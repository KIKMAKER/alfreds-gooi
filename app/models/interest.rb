class Interest < ApplicationRecord
  belongs_to :suburb, optional: true

  validates :name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  after_create_commit :notify!

  private

  def notify!
    InterestMailer.with(interest: self).new_interest_email.deliver_now
    InterestMailer.with(interest: self).confirmation_email.deliver_now
  end
end
