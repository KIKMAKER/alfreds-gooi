class User < ApplicationRecord
  before_validation :make_international
  before_create :generate_referral_code

  enum role: { customer: 0, driver: 1, admin: 2, drop_off: 3 }
  has_many :subscriptions, dependent: :nullify
  has_many :invoices, through: :subscriptions
  has_many :collections, through: :subscriptions
  has_many :drivers_days
  has_many :payments, dependent: :destroy
  # Referrer: The user who referred others
  has_many :referrals_as_referrer,
           class_name: 'Referral',
           foreign_key: 'referrer_id',
           dependent: :destroy

  # Referees: The users who were referred by this user
  has_many :referees,
           through: :referrals_as_referrer,
           source: :referee

  # Referrals where this user is the referee (was referred by someone else)
  has_many :referrals_as_referee,
           class_name: 'Referral',
           foreign_key: 'referee_id',
           dependent: :destroy

  # Referrer: The user who referred this user
  has_one :referrer,
          through: :referrals_as_referee,
          source: :referrer

          
  accepts_nested_attributes_for :subscriptions

  before_destroy :nullify_subscriptions

  # Callbacks

  # Custom validation
  # validates :referral_code, uniqueness: true
  validate :valid_international_phone_number

  # custom methods

  # current subscription

  def current_sub
    subscriptions.last
  end

  def total_collections
    subscriptions.joins(:collections).count
  end

  def duplicate_subscription_with_collections(num_collections)
    # Find the user's last subscription

    last_subscription = subscriptions.order(created_at: :desc).first
    return nil unless last_subscription

    # Duplicate the subscription
    new_subscription = last_subscription.dup
    new_subscription.start_date = last_subscription.start_date + last_subscription.duration.months

    new_subscription.is_new_customer = false
    if new_subscription.save!
      # Find the last n collections of the prior subscription
      collections_to_reassign = last_subscription.collections.order(time: :desc).limit(num_collections)

      # Reassign collections to the new subscription
      collections_to_reassign.update_all(subscription_id: new_subscription.id)
      last_subscription.completed!

      # Return the new subscription
      new_subscription
    else
      # Handle errors during subscription duplication
      Rails.logger.error("Failed to create new subscription: #{new_subscription.errors.full_messages.join(', ')}")
      nil
    end
  end

  def generate_referral_code
    self.referral_code ||= SecureRandom.hex(3).upcase
  end


  private

  ## phone number validation

  def make_international
    puts "Before: #{self.phone_number}"
    # return if valid_international_phone_number()

    self.phone_number = starts_0? ? "+27#{phone_number[1..]}" : phone_number
    puts "After: #{self.phone_number}"
  end

  def starts_0?
    phone_number.start_with?('0')
  end
  # Custom validation method

  def valid_international_phone_number
    return if /\A\+27\d{9}\z/.match?(phone_number)

    if /\A\+\d{9,13}\z/.match?(phone_number)
      true
    else
      puts errors.add(:phone_number, "#{phone_number} for #{first_name} is not a valid south african or international phone number")
      false
    end
  end

  # before create


  # before destroy
  def nullify_subscriptions
    self.subscriptions.update_all(user_id: nil)
  end


  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable


end
