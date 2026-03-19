class Interest < ApplicationRecord
  SUBURBS = [
    "Athlone", "Bellville", "Bellville South", "Bloubergstrand", "Bothasig",
    "Brackenfell", "Brooklyn", "Century City", "Crawford", "Durbanville",
    "Edgemead", "Elsies River", "Epping", "Glencairn", "Goodwood",
    "Gugulethu", "Hanover Park", "Khayelitsha", "Kommetjie", "Kraaifontein",
    "Kuils River", "Langa", "Lansdowne", "Lentegeur", "Maitland",
    "Manenberg", "Milnerton", "Mitchells Plain", "Monte Vista",
    "Montague Gardens", "Noordhoek", "Nyanga", "Ocean View", "Ottery",
    "Paarden Eiland", "Parow", "Parklands", "Pelikan Park", "Phillippi",
    "Pinelands", "Red Hill", "Richwood", "Rugby", "Scarborough",
    "Simon's Town", "Strandfontein", "Sunningdale", "Surrey Estate",
    "Table View", "Thornton", "Wetton", "Ysterplaat"
  ].sort.push("Other").freeze

  validates :name, :email, :suburb, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :suburb, inclusion: { in: SUBURBS, message: "is not a recognised unserviced suburb" }

  after_create_commit :notify!

  private

  def notify!
    InterestMailer.with(interest: self).new_interest_email.deliver_now
    InterestMailer.with(interest: self).confirmation_email.deliver_now
  end
end
