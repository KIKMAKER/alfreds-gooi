class Suburb < ApplicationRecord
  enum :status, %i[active drop_off_only waitlist target]
  enum :collection_day, Date::DAYNAMES

  has_many :subscriptions, dependent: :restrict_with_error
  has_many :drop_off_sites, dependent: :restrict_with_error
  has_many :business_profiles, dependent: :restrict_with_error
  has_many :interests, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :collection_day, presence: true, if: :active?

  before_validation :generate_slug, on: :create, if: -> { slug.blank? }

  # Used to drive the client-side suburb-by-day pickers (signup form, service map)
  # without duplicating the day->suburbs lookup that used to live as parallel
  # string-array constants on Subscription/DropOffSite/SuburbSpotlight.
  def self.names_by_day
    %w[Monday Tuesday Wednesday Thursday].index_with { |day| active.where(collection_day: day).order(:name).pluck(:name) }
  end

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
