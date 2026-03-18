class Contact < ApplicationRecord
  belongs_to :subscription
  has_many :whatsapp_messages, dependent: :nullify

  validates :first_name, presence: true
  validates :phone_number, presence: true,
            uniqueness: { scope: :subscription_id, message: "already exists for this subscription" }
  validates :relationship, inclusion: {
    in: %w[owner spouse housemate family other housekeeper],
    allow_blank: true
  }

  # Scopes
  scope :primary, -> { where(is_primary: true) }
  scope :can_receive_whatsapp, -> { where(whatsapp_opt_out: false).where.not(phone_number: [nil, '']) }
  scope :opted_in, -> { where(whatsapp_opt_out: false) }
  scope :opted_out, -> { where(whatsapp_opt_out: true) }

  # Format phone for WhatsApp
  def formatted_phone
    return nil if phone_number.blank?

    # Already formatted
    return phone_number if phone_number.start_with?('+')

    # South African number without country code
    if phone_number.start_with?('0')
      "+27#{phone_number[1..]}"
    else
      "+#{phone_number}"
    end
  end

  # WhatsApp capability check
  def can_receive_whatsapp?
    phone_number.present? && !whatsapp_opt_out
  end

  # Opt-out/in methods
  def opt_out_of_whatsapp!
    update(whatsapp_opt_out: true)
  end

  def opt_in_to_whatsapp!
    update(whatsapp_opt_out: false)
  end

  # Display name
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  def display_name
    if is_primary
      "#{full_name} (Owner)"
    elsif relationship.present?
      "#{full_name} (#{relationship.titleize})"
    else
      full_name
    end
  end
end
