class FestivalEvent < ApplicationRecord
  has_many :festival_participants, dependent: :destroy
  has_many :festival_waste_logs, dependent: :destroy

  validates :name, :start_date, :end_date, presence: true
  validate :end_date_after_start_date

  def self.tracking_blurb
    today = Date.today
    if (current = where("start_date <= ? AND end_date >= ?", today, today).order(:start_date).first)
      "We are currently tracking for #{current.name}."
    elsif (upcoming = where("start_date > ?", today).order(:start_date).first)
      "We'll soon start tracking for #{upcoming.name}."
    elsif (recent = order(end_date: :desc).first)
      "We recently tracked for #{recent.name}."
    end
  end

  def day_count
    (end_date - start_date).to_i + 1
  end

  def day_label(number)
    date = start_date + (number - 1).days
    "Day #{number} – #{date.strftime('%a %-d %b')}"
  end

  private

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, "must be on or after start date") if end_date < start_date
  end
end
