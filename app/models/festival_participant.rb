class FestivalParticipant < ApplicationRecord
  belongs_to :festival_event
  has_many :festival_waste_logs

  validates :name, presence: true
  validates :pin, length: { minimum: 4 }, allow_nil: true
end
