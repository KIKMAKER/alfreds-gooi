class User < ApplicationRecord
  before_validation :make_international
  # after_create_commit :create_initial_invoice # unless subscriptions.count > 1

  enum role: { customer: 0, driver: 1, admin: 2, drop_off: 3 }
  has_many :subscriptions, dependent: :nullify
  has_many :invoices, through: :subscriptions
  has_many :collections, through: :subscriptions
  has_many :drivers_days
  has_many :payments, dependent: :destroy

  accepts_nested_attributes_for :subscriptions

  before_destroy :nullify_subscriptions


  # Callbacks

  # Custom validation
  validate :valid_international_phone_number
  validates :customer_id, uniqueness: true
  # custom methods

  # current subscription

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

  # before destroy
  def nullify_subscriptions
    self.subscriptions.update_all(user_id: nil)
  end



  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable


end
