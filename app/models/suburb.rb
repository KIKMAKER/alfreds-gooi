class Suburb < ApplicationRecord
  enum :status, %i[active drop_off_only waitlist target]

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens" }

  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  private

  def generate_slug
    base = name.to_s.downcase.gsub(/[^a-z0-9\s\-]/, "").gsub(/\s+/, "-").strip
    candidate = base
    n = 1
    while Suburb.exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end
end
