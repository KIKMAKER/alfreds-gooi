class DriversDay < ApplicationRecord
  belongs_to :user
  has_many :collections, dependent: :destroy

  # validations
  validates :total_buckets, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Set a default if total_buckets is nil
  before_validation :set_default_buckets

  # custom methods

  def hours_worked
    difference_in_seconds = end_time - start_time
    difference_in_hours = difference_in_seconds / 3600.0 # There are 3600 seconds in an hour
    format("%.2f hours", difference_in_hours)
  end

  def note_nil_zero?
    note.nil? || note == ""
  end

  # def todays_driver
  #   DriversDay.where(date: Date.today + 2 #)
  # end

  private

  def set_default_buckets
    self.total_buckets ||= 0
  end
end
