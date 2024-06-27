class Subscription < ApplicationRecord
  belongs_to :user
  has_many :collections
  has_many :invoices, dependent: :destroy
  has_many :contacts, dependent: :destroy

  # accepts_nested_attributes_for :contacts
  accepts_nested_attributes_for :user

  ## VALIDATIONS
  # validates :street_address, :suburb, :plan, :duration, presence: true

  ## ENUMS
  enum status: %i[active pause pending]
  enum plan: %i[once_off standard XL]
  enum collection_day: Date::DAYNAMES

  # SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Imizamo Yethu", "Llandudno", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap (Malay Quarter)", "Devil's Peak Estate", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "Lower Vrede (District Six)", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Walmer Estate (District Six)", "Woodstock (including Upper Woodstock)", "Zonnebloem (District Six)", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kenwyn", "Kirstenhof", "Meadowridge", "Mowbray", "Ndabeni", "Newlands", "Observatory", "Pinelands", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "SouthField", "Steenberg", "Tokai", "Wynberg", "Capri Village", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "Simon's Town", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze
  SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap (Malay Quarter)", "Devil's Peak Estate", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "Lower Vrede (District Six)", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Walmer Estate (District Six)", "Woodstock (including Upper Woodstock)", "Zonnebloem (District Six)", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kenwyn", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "SouthField", "Steenberg", "Tokai", "Wynberg", "Capri Village", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze


  # customised methods

  def total_collections
    collections.count
  end

  def skipped_collections
    collections.where(skip: true).count
  end

  def total_bags
    collections.sum(:bags)
  end

  def total_buckets
    collections.sum(:buckets)
  end

  def total_bags_last_n_months(n)
    collections.where("created_at >= ?", n.months.ago).sum(:bags)
  end

  def total_buckets_last_n_months(n)
    collections.where("created_at >= ?", n.months.ago).sum(:buckets)
  end

  def self.active_subs_for(day)
    all.where(collection_day: day).includes(:collections).order(:collection_order)
  end

  def self.count_skip_subs_for(day)
    active_subs_for(day).where(collections: { skip: true }).distinct.count
  end

  def self.humanized_plans
    {
      once_off: 'Once Off',
      standard: 'Standard',
      XL: 'Extra Large'
    }
  end
end
