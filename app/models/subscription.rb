class Subscription < ApplicationRecord
  belongs_to :user
  has_many :collections
  has_many :invoices, dependent: :destroy
  has_many :contacts, dependent: :destroy

  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?


  after_create do
    self.set_customer_id
    self.set_suburb
    self.set_collection_day
  end

  # accepts_nested_attributes_for :contacts
  accepts_nested_attributes_for :user

  ## VALIDATIONS
  # validates :street_address, :suburb, :plan, :duration, presence: true

  ## ENUMS
  enum status: %i[active pause pending]
  enum plan: %i[once_off standard XL]
  enum collection_day: Date::DAYNAMES

  SUBURBS = ["Bakoven", "Bantry Bay", "Cape Town", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap (Malay Quarter)", "Devil's Peak Estate", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "Lower Vrede (District Six)", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Walmer Estate (District Six)", "Woodstock (including Upper Woodstock)", "Zonnebloem (District Six)", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kenwyn", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "SouthField", "Steenberg", "Tokai", "Witteboomen", "Wynberg", "Capri Village", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze

  TUESDAY_SUBURBS  = ["Bergvliet", "Bishopscourt", "Claremont", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kenwyn", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "SouthField", "Steenberg", "Tokai", "Wynberg", "Capri Village", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze

  WEDNESDAY_SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap (Malay Quarter)", "De Waterkant", "Foreshore", "Schotsche Kloof",  "Woodstock", "Zonnebloem (District Six)", "Constantia", "Witteboomen"].sort!.freeze

  THURSDAY_SUBURBS = ["Devil's Peak Estate", "Gardens", "Higgovale", "Lower Vrede (District Six)", "Oranjezicht", "Salt River", "Tamboerskloof", "University Estate", "Vredehoek", "Walmer Estate (District Six)", "Woodstock", "Observatory", "Salt River"].sort!.freeze

  # customised methods

  def set_suburb
    parts = street_address.split(',')
    if parts.length >= 3
      # Assume the suburb is the second to last part before the province and country
      suburb = parts[-3].strip
      # return suburb
      puts suburb
    end
    if SUBURBS.include?(suburb)
      update(suburb: suburb)
      puts "found the sub in the list of subs"
    end
    nil
  end

  def calculate_next_collection_day
    target_day = Date::DAYNAMES.index(collection_day.capitalize)
    current_day = Date.today.wday
    days_until_next_collection = (target_day - current_day) % 7
    days_until_next_collection = 7 if days_until_next_collection.zero?
    Date.today + days_until_next_collection
  end

  def set_collection_day
    if TUESDAY_SUBURBS.include?(suburb)
      update(collection_day: "Tuesday")
    elsif WEDNESDAY_SUBURBS.include?(suburb)
      update(collection_day: "Wednesday")
    elsif THURSDAY_SUBURBS.include?(suburb)
      update(collection_day: "Thursday")
    else
      puts "it seems there was an issue with the suburb allocation"
    end
  end

  def set_customer_id
    last_customer_id = Subscription.order(:customer_id).last.customer_id || "GFWC000"
    prefix = last_customer_id[0...4]
    number = last_customer_id[4..].to_i
    new_number = number + 1
    new_customer_id = "#{prefix}#{new_number.to_s.rjust(3, '0')}"
    update(customer_id: new_customer_id)
    self.user.update(customer_id: new_customer_id)
  end


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
