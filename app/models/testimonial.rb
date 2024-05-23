class Testimonial < ApplicationRecord
  belongs_to :user, optional: true

  validates :content, presence: true

  def self.import_from_csv(file_path)
    CSV.foreach(file_path, headers: true) do |row|
      Testimonial.create!(content: row['Testimonial'], ranking: row['Ranking'])
    end
    puts "Testimonials imported successfully!"
  end
end
