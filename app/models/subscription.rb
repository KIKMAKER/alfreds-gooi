class Subscription < ApplicationRecord
  belongs_to :user
  has_many :collections
  has_many :contacts, dependent: :destroy

  accepts_nested_attributes_for :contacts

  ## VALIDATIONS
  validates :street_address, :suburb, :plan, :duration, presence: true

  ## ENUMS
  enum status: %i[active pause pending]
  enum plan: %i[once_off standard XL]
  enum collection_day: Date::DAYNAMES

  # customised methods

  def self.active_subs_for(day)
    all.where(collection_day: day).includes(:collections).order(:collection_order)
  end

  def self.count_skip_subs_for(day)
    active_subs_for(day).where(collections: { skip: true }).distinct.count
  end

  def self.humanized_plans
    {
      once_off: 'Once Off',
      standard: 'Standard',
      XL: 'Extra Large'
    }
  end
end
