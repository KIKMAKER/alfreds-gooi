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

  def needs_bags?
    needs_bags
  end
end
