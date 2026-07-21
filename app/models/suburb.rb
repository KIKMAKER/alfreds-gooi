class Suburb < ApplicationRecord
  enum :status, %i[active drop_off_only waitlist target]
  enum :collection_day, Date::DAYNAMES

  has_many :subscriptions, dependent: :restrict_with_error
  has_many :drop_off_sites, dependent: :restrict_with_error
  has_many :business_profiles, dependent: :restrict_with_error
  has_many :interests, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :collection_day, presence: true, if: :active?
  # Compares the raw status value (not the waitlist? method below) to avoid circularity —
  # waitlist? itself depends on launch_date being present.
  validates :launch_date, presence: true, if: -> { status == "waitlist" }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  # Used to drive the client-side suburb-by-day pickers (signup form, service map)
  # without duplicating the day->suburbs lookup that used to live as parallel
  # string-array constants on Subscription/DropOffSite/SuburbSpotlight.
  def self.names_by_day
    %w[Monday Tuesday Wednesday Thursday].index_with { |day| active.where(collection_day: day).order(:name).pluck(:name) }
  end

  # Overrides the enum-generated waitlist? (which would just check status == "waitlist").
  # Single source of truth for "is this suburb currently taking locked-in-rate launch
  # signups" — new-signup validation, payment processing, and the public launch page all
  # call this rather than re-deriving it from status/date separately.
  def waitlist?
    status == "waitlist" && launch_date.present?
  end

  # Any non-active status -> waitlist, opening the public launch/signup window.
  # update (not update!) so any other validation failure returns false rather than
  # raising — callers only need to branch on truthiness.
  def start_launch!
    return false if launch_date.blank?
    return false if active?
    update(status: :waitlist)
  end

  # waitlist -> active: the manual "we're live" moment that closes the signup offer.
  # launch_date is left untouched — it stays as the historical record of when the
  # suburb launched, and waitlist? already returns false once status flips to active.
  # Uses update (not update!): a waitlisted suburb missing collection_day would
  # otherwise raise RecordInvalid here instead of failing the transition cleanly.
  def go_live!
    return false unless waitlist?
    return false unless update(status: :active)

    # Subscriptions paid for while this suburb was still on the waitlist stayed
    # pending with a pre-computed near-launch start_date (see
    # Subscription#activate_subscription/#deferred_launch_start_date) — finalize
    # them now rather than waiting on a background job (there are none in prod).
    # Their first collection couldn't be created at payment time (the suburb
    # wasn't live yet), so it's created here instead, now that it is.
    subscriptions.pending.joins(:invoices).merge(Invoice.paid).distinct.find_each do |subscription|
      subscription.finalize_deferred_activation!
      CreateFirstCollectionJob.perform_now(subscription)
    end
    true
  end

  private

  def generate_slug
    base = name.to_s.downcase.gsub(/[^a-z0-9\s\-]/, "").gsub(/\s+/, "-").strip
    candidate = base
    n = 1
    while Suburb.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
