class Interest < ApplicationRecord
  validates :name, :email, :suburb, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  after_create_commit :notify!

  private
  def notify!
    InterestMailer.with(interest: self).new_interest_email.deliver_now
  end
end
