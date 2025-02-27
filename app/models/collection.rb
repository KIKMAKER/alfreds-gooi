class Collection < ApplicationRecord
  belongs_to :subscription, optional: true
  belongs_to :drivers_day, optional: true
  has_one :user, through: :subscription
  acts_as_list scope: :drivers_day


  # Scopes
  scope :recent, -> { order(date: :desc) }

  # Custom methods
  def done?
    is_done
  end

  def skip?
    skip
  end

  def kiki_note_nil_zero?
    kiki_note.nil? || kiki_note == ""
  end

  # Method to check if the collection is for today's date
  def today?
    self.date == Date.current
  end

  # Save data outside of heroku
  def self.to_csv
    attributes = %w[id created_at updated_at subscription_id date kiki_note alfred_message bags buckets is_done skip drivers_day_id new_customer buckets]

    CSV.generate(headers: true) do |csv|
      csv << attributes

      all.find_each do |collection|
        csv << attributes.map { |attr| collection.send(attr) }
      end
    end
  end

end
