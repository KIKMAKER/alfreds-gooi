class User < ApplicationRecord

  enum role: %i[customer driver admin]
  has_many :subscriptions
  has_many :collections, through: :subscriptions
  has_many :drivers_day
  # Callbacks
  # before_validation :make_international
  # Validations
  # validate valid_international_phone_number?
  ## Custom methods

  def self.valid_international_phone_number?
    errors.add(:phone_number, 'is not a valid international phone number') unless /\A\+27\d{9}\z/.match?(phone_number)
  end

  def self.starts_0?
    phone_number.start_with?('0')
  end

  def self.make_international
    return phone_number if valid_international_phone_number?

    if starts_0?
      "+27#{phone_number[1..]}"
    else
      phone_number
    end
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable


end
