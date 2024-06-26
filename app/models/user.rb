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
    # product = Product.find_by(title: "Starter kit")
    # return unless product

    # invoice = invoices.create(
    #   issue_date: Time.current,
    #   due_date: Time.current + 0.5.month,
    # )

    # invoice.invoice_items.create(
    #   product: product,
    #   amount: product.price,
    #   quantity: duration
    # )
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




  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :timeoutable


end
