# What Gooi owes a charging drop-off site for one calendar month.
#
# Deliberately not an Invoice: we are the payer, so there is nothing to bill. A
# row is a snapshot of kg x rate taken when the payment request goes out, so a
# later rate change cannot silently reprice a month we have already told a site
# about.
#
# Gooi only pays sites that are listed facilities (letter approved) — see
# DropOffSite#payable?.
class DisposalPayment < ApplicationRecord
  class NotPayable < StandardError; end

  belongs_to :drop_off_site

  enum :status, %i[requested paid]

  validates :period, presence: true, uniqueness: { scope: :drop_off_site_id }
  validates :kg, :fee_per_kg, :amount, numericality: { greater_than_or_equal_to: 0 }

  # Creates, or refreshes, the request for a month. Returns nil when there is
  # nothing to ask for (free site, or no billable kg). A paid month is left
  # untouched.
  def self.request_for!(site, month:)
    return unless site.charges_disposal_fee?

    period = month.beginning_of_month
    fees = site.fees_for(year: period.year, month: period.month)
    return unless fees[:fee].positive?

    payment = find_or_initialize_by(drop_off_site: site, period: period)
    return payment if payment.paid?

    payment.update!(kg: fees[:kg], fee_per_kg: site.fee_per_kg, amount: fees[:fee], requested_at: Time.current)
    payment
  end

  def mark_paid!
    raise NotPayable, "#{drop_off_site.name} is not a listed facility yet" unless drop_off_site.payable?

    update!(status: :paid, paid_at: Time.current)
  end

  def month_label
    period.strftime("%B %Y")
  end
end
