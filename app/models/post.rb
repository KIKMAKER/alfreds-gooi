class Post < ApplicationRecord
  validates :title, :body, :slug, presence: true
  validates :slug, uniqueness: true

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  scope :published, -> { where(published: true).order(published_at: :desc) }

  def to_param
    slug
  end

  private

  def generate_slug
    self.slug = title.parameterize
  end
end
