class Date
  def next_occurring(weekday)
    days_ahead = (weekday - self.wday) % 7
    days_ahead = 7 if days_ahead.zero? # Ensure it moves to the next week if today matches the weekday
    self + days_ahead
  end
end
