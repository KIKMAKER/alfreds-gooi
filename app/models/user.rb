class User < ApplicationRecord

  enum role: %i[customer driver admin]
  has_many :subscriptions
  has_many :collections, through: :subscriptions
  has_many :drivers_day

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
