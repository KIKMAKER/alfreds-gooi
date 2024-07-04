class User < ApplicationRecord
  before_validation :make_international
  # after_create_commit :create_initial_invoice # unless subscriptions.count > 1

  enum role: { customer: 0, driver: 1, admin: 2, drop_off: 3 }
  has_many :subscriptions, dependent: :destroy
  has_many :collections, through: :subscriptions
  has_many :drivers_days
  has_many :invoices, dependent: :destroy


  accepts_nested_attributes_for :subscriptions

  # Callbacks

  # Custom validation
  validate :valid_international_phone_number

  # custom methods

  # current subscription

  def current_sub
    subscriptions.last
  end

  # initial invoice generation (after sign up)

  def create_initial_invoice
    subscription = self.subscriptions.first
    return unless subscription
    p subscription.plan
    p "hello"
    starter_kit_title = determine_starter_kit_title(subscription.plan)
    starter_kit = Product.find_by(title: starter_kit_title)
    p starter_kit.price
    subscription_title = determine_subscription_title(subscription.duration, subscription.plan)
    subscription_product = Product.find_by(title: subscription_title)
    return unless subscription_product
    p subscription_product.price
    invoice = Invoice.create!(
      subscription_id: subscription.id,
      user_id: self.id,
      issued_date: Time.current,
      due_date: Time.current + 1.month,
      total_amount: subscription_product.price + starter_kit.price
    )
    p invoice.total_amount

    InvoiceItem.create!(
      invoice_id: invoice.id,
      product_id: starter_kit.id,
      amount: starter_kit.price,
      quantity: 1
    )

    InvoiceItem.create!(
      invoice_id: invoice.id,
      product_id: subscription_product.id,
      amount: subscription_product.price,
      quantity: 1
    )

    invoice.invoice_items.sum('amount * quantity')
    invoice.save!
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

  private
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

  # infer starter kit based on sub plan

  def determine_starter_kit_title(plan)
    case plan
    when "standard"
      "Standard Starter Kit"
    when "XL"
      "XL Starter Kit"
    else
      puts "Invalid plan"
    end
  end

  # infer product title for first invoice based on subscription plan and duration

  def determine_subscription_title(duration, plan)
    case plan
    when "standard"
      case duration
      when 1
        "Standard 1 month subscription"
      when 3
        "Standard 3 month subscription"
      when 6
        "Standard 6 month subscription"
      else
        puts "Invalid duration"
      end
    when "XL"
      case duration
      when 1
        "XL 1 month subscription"
      when 3
        "XL 3 month subscription"
      when 6
        "XL 6 month subscription"
      else
        puts "Invalid duration"
      end
    else
      puts "Invalid plan"
    end
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable


end
