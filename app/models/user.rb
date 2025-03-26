class User < ApplicationRecord
  enum :role, %i[customer driver admin drop_off]

  # Associations
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

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable

  # Callbacks

  before_validation :make_international
  before_validation :generate_referral_code, on: :create
  before_validation :set_customer_id, on: :create
  before_destroy :nullify_subscriptions


  # Custom validation
  validate :valid_international_phone_number
  # validates :customer_id, uniqueness: true
  validates :referral_code, uniqueness: true, allow_nil: true
  # custom methods

  def whatsapp_notification_link
    return unless subscriptions.any?

    message = case current_sub.remaining_collections.truncate
              when 0
                "Hello! Your subscription with Gooi has come to an end. We hope you want to continue gooiiing. Log in to alfred.gooi.me with #{email} to resubscribe! Your password should be 'password' unless you already changed it."
              when -Float::INFINITY..-1
                "Hello! Your subscription lapsed #{-current_sub.remaining_collections.truncate} weeks ago. Please log in to alfred.gooi.me with #{email} to resubscribe! Your password should be 'password' unless you already changed it."
              else
                "Hello! Your subscription will end soon (in about #{current_sub.remaining_collections.truncate} weeks). Log in to alfred.gooi.me with #{email} to resubscribe! Your password should be 'password' unless you already changed it."
              end

    "https://wa.me/#{phone_number.gsub(/\D/, '')}?text=#{ERB::Util.url_encode(message)}"
  end

  def generate_whatsapp_link(message)
    "https://wa.me/#{phone_number.gsub(/\D/, '')}?text=#{ERB::Util.url_encode(message)}"
  end



  def current_sub
    subscriptions.order(start_date: :desc).first
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



  private

  def generate_referral_code
    self.referral_code ||= loop do
      code = SecureRandom.hex(3).upcase
      break code unless User.exists?(referral_code: code)
    end
  end


  # def generate_unique_code
  #   loop do
  #     code = SecureRandom.hex(3).upcase
  #     break code unless User.exists?(referral_code: code)
  #   end
  # end

  # Callbacks

  # before create

  # after create
  def set_customer_id
    return if self.customer_id.present?
    customers = User.where(role: 'customer').where.not(customer_id: nil)
    last_id = (customers.sort_by { |customer| customer.customer_id[4..-1].to_i }.last&.customer_id || "")[4..-1].to_i
    next_customer_id = "GFWC" + (last_id + 1).to_s
    self.customer_id = next_customer_id
  end

 # before destroy
  def nullify_subscriptions
    self.subscriptions.update_all(user_id: nil)
  end

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

  # Validations

  def valid_international_phone_number
    return if /\A\+27\d{9}\z/.match?(phone_number)

    if /\A\+\d{9,13}\z/.match?(phone_number)
      true
    else
      puts errors.add(:phone_number, "#{phone_number} for #{first_name} is not a valid south african or international phone number")
      false
    end
  end

end
