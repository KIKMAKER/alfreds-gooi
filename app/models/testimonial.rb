class Testimonial < ApplicationRecord
  belongs_to :user
  has_one_attached :photo

  validates :content, presence: true, length: { minimum: 10, maximum: 500 }
  validates :public, inclusion: { in: [true, false] }

  # Scopes
  scope :public_testimonials, -> { where(public: true).order(created_at: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # Photo validation
  validate :acceptable_photo

  private

  def acceptable_photo
    return unless photo.attached?

    unless photo.blob.byte_size <= 5.megabytes
      errors.add(:photo, "is too big (max 5MB)")
    end

    acceptable_types = ["image/jpeg", "image/jpg", "image/png", "image/gif"]
    unless acceptable_types.include?(photo.blob.content_type)
      errors.add(:photo, "must be a JPEG, PNG, or GIF")
    end
  end
end
