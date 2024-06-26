class User < ApplicationRecord
  before_validation :make_international
  after_create :create_initial_invoice # unless subscriptions.count > 1

  enum role: %i[customer driver admin drop_off]
  has_many :subscriptions, dependent: :destroy
  has_many :collections, through: :subscriptions
  has_many :drivers_days
  has_many :invoices


  accepts_nested_attributes_for :subscriptions

  # Callbacks

  # Custom validation
  validate :valid_international_phone_number

  # custom methods

  # initial invoice generation (after sign up)

  def create_initial_invoice
    subscription = self.subscriptions.first
    return unless subscription

    product_title = determine_product_title(subscription.duration, subscription.plan)
    product = Product.find_by(title: product_title)
    return unless product

    invoice = self.invoices.create(
      issue_date: Time.current,
      due_date: Time.current + 0.5.month,
      total_amount: product.price
    )

    invoice.invoice_items.create(
      product: product,
      amount: product.price,
      quantity: 1
    )
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

  # infer product title for first invoice based on subscription plan and duration

  def determine_product_title(duration, plan)
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
