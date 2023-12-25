class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections

  # custom methods
  def hours_worked
    difference_in_seconds = end_time - start_time
    difference_in_hours = difference_in_seconds / 3600.0 # There are 3600 seconds in an hour
    format("%.2f hours", difference_in_hours)
  end
end
