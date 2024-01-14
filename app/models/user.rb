class User < ApplicationRecord
  before_validation :make_international

  enum role: %i[customer driver admin drop_off]
  has_many :subscriptions
  has_many :collections, through: :subscriptions
  has_many :drivers_day

  # Callbacks

  # Custom validation
  validate :valid_international_phone_number

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
  def valid_international_phone_number
    return if /\A\+27\d{9}\z/.match?(phone_number)
    if /\A\+\d{9,13}\z/.match?(phone_number)
      true
    else
      puts errors.add(:phone_number, "#{phone_number} for #{first_name} is not a valid south african or international phone number")
      false
    end
  end

  # Custom validation method



  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable


end
