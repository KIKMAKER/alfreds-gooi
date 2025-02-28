class Referral < ApplicationRecord
  belongs_to :referrer, class_name: 'User'
  belongs_to :referee, class_name: 'User'
  belongs_to :subscription, optional: true # Optional because not all referrals might be linked to a subscription immediately

  validates :referrer_id, presence: true
  validates :referee_id, presence: true

  enum status: %i[pending completed]
end
