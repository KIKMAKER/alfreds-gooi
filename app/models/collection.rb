class Collection < ApplicationRecord
  belongs_to :subscription
  belongs_to :drivers_day


  # Scopes
  scope :recent, -> { order(date: :desc) }

  # Custom methods
  def done?
    is_done
  end

  def skip?
    skip
  end

  # Method to check if the collection is for today's date
  def today?
    self.date == Date.current
  end
end
