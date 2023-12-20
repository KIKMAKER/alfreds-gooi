class Subscription < ApplicationRecord
  belongs_to :user
  has_many :collections

  ## VALIDATIONS

  validates :street_address, :suburb, :plan, :duration, presence: true

  ## ENUMS
  enum status: %i[active pause pending]
  enum plan: %i[once_off standard XL]
  enum collection_day: %i[Sunday Monday Tuesday Wednesday Thursday Friday Saturday]

  def self.humanized_plans
    {
      once_off: 'Once Off',
      standard: 'Standard',
      XL: 'Extra Large'
    }
  end

  def is_paused?
    is_paused
  end

end
