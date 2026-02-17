class CommercialInquiry < ApplicationRecord
  belongs_to :user

  validates :business_name, presence: true
  validates :business_address, presence: true
  validates :estimated_buckets, presence: true, numericality: { greater_than: 0 }

  enum status: {
    pending: 'pending',
    contacted: 'contacted',
    converted: 'converted',
    declined: 'declined'
  }

  COLLECTION_FREQUENCIES = ['Once per week', 'Twice per week', '3+ times per week'].freeze

  after_initialize :set_default_status, if: :new_record?

  private

  def set_default_status
    self.status ||= :pending
  end
end
