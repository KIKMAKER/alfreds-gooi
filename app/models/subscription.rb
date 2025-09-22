class Subscription < ApplicationRecord
  belongs_to :user
  has_many :collections, dependent: :nullify
  has_many :invoices, dependent: :nullify
  has_many :invoice_items, through: :invoices
  has_many :referrals, dependent: :nullify

  before_create do
    self.set_customer_id unless self.customer_id
    # self.set_suburb
  end
  before_validation :set_collection_day, if: -> { will_save_change_to_street_address? || will_save_change_to_suburb? }
  before_validation :canonicalize_suburb
  SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap", "De Waterkant", "Foreshore", "Gardens", "Higgovale", "District Six", "Ndabeni", "Oranjezicht", "Salt River", "Schotsche Kloof", "Tamboerskloof", "University Estate", "Vredehoek", "Woodstock (including Upper Woodstock)", "Bergvliet", "Bishopscourt", "Claremont", "Constantia", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Observatory", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Witteboomen", "Wynberg", "Clovelly", "Fish Hoek", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze
  validates :suburb, inclusion: { in: SUBURBS }
  validates :street_address, presence: true
  geocoded_by :street_address
  after_validation :geocode, if: :will_save_change_to_street_address?



  # accepts_nested_attributes_for :contacts
  # accepts_nested_attributes_for :user

  # scopes
  scope :pending, -> { where(status: :pending) }
  scope :active, -> { where(status: :active) }
  scope :paused, -> { where(status: :paused) }
  scope :completed, -> { where(status: :completed) }
  scope :order_by_user_name, -> { joins(:user).order('users.first_name ASC') }

  ## VALIDATIONS
  # validates :street_address, :suburb, :plan, :duration, presence: true

  ## ENUMS
  enum :status, %i[pending active pause completed legacy]
  enum :plan, %i[once_off Standard XL]
  enum :collection_day, Date::DAYNAMES

  TUESDAY_SUBURBS  = ["Bergvliet", "Bishopscourt", "Claremont", "Diep River", "Grassy Park", "Harfield Village", "Heathfield", "Kenilworth", "Kirstenhof", "Meadowridge", "Mowbray", "Newlands", "Plumstead", "Retreat", "Rondebosch", "Rondebosch East", "Rosebank", "Southfield", "Steenberg", "Tokai", "Wynberg", "Clovelly", "Fish Hoek", "Glencairn", "Kalk Bay", "Lakeside", "Marina da Gama", "Muizenberg", "St James", "Sunnydale", "Sun Valley", "Vrygrond"].sort!.freeze
  WEDNESDAY_SUBURBS = ["Bakoven", "Bantry Bay", "Camps Bay", "Cape Town", "Clifton", "Fresnaye", "Green Point", "Hout Bay", "Mouille Point", "Sea Point", "Three Anchor Bay", "Bo-Kaap", "De Waterkant", "Foreshore", "Schotsche Kloof", "Woodstock (including Upper Woodstock)", "Constantia", "Witteboomen"].sort!.freeze
  THURSDAY_SUBURBS = ["Gardens", "Higgovale", "District Six", "Oranjezicht", "Salt River", "Tamboerskloof", "University Estate", "Vredehoek", "Observatory", ].sort!.freeze
  FUTURE_SUBURBS = ["Sunnydale", "Sun Valley", "Noordhoek", "Glencairn", "Milnerton", "Tableview", "Grassy Park"]
  LEGACY_TO_CANONICAL = {
                          "Devil's Peak Estate"            => "Vredehoek",
                          "Zonnebloem (District Six)"      => "District Six",
                          "Walmer Estate (District Six)"   => "District Six",
                          "Lower Vrede (District Six)"     => "District Six",
                        }.freeze
  def calculate_next_collection_day
    target_day = Date::DAYNAMES.index(collection_day.capitalize)
    current_day = Time.zone.today.wday # Use Time.zone.today for time zone awareness
    days_until_next_collection = (target_day - current_day) % 7
    days_until_next_collection = 7 if days_until_next_collection.zero?
    puts "next collection day: #{Time.zone.today + days_until_next_collection}"
    Time.zone.today + days_until_next_collection # Use Time.zone.today here as well
  end

  def total_collections
    collections.count
  end

  def remaining_collections
    return nil if duration.nil?
    total = duration * 4.2
    remaining = total.ceil - self.total_collections
    return remaining
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

  def is_paused?
    # added && condition to prevent calculation of holiday when holiday is nil
    is_paused || (holiday_start != nil && (Date.today >= holiday_start && Date.today <= holiday_end))
  end

  def complete?
    status == "completed"
  end

  def end_date!
    self.update!(end_date: (start_date + duration.months).to_date) if start_date
  end

  def set_collection_day
    if TUESDAY_SUBURBS.include?(suburb)
      self.collection_day = "Tuesday"
    elsif WEDNESDAY_SUBURBS.include?(suburb)
      self.collection_day = "Wednesday"
    elsif THURSDAY_SUBURBS.include?(suburb)
      self.collection_day = "Thursday"
    else
      puts "it seems there was an issue with the suburb allocation for #{user.first_name} in #{suburb}"
    end
  end

  def set_customer_id
    return if self.customer_id.present?
    self.customer_id = user.customer_id
  end

  def suggested_start_date(payment_date: Time.zone.today)
    last_sub = user.subscriptions.completed.order(end_date: :desc).first
    return payment_date unless last_sub

    last_end = last_sub.end_date.to_date
    return payment_date unless last_end

    days_since = (payment_date - last_end).to_i
    expected = (days_since / 7.0).floor
    actual = user.collections.where(date: (last_end + 1.day)..payment_date).count

    if actual >= (expected/2)
      last_end + 7
    else
      payment_date
    end
  end

  def has_future_subscription?(from: Date.today, within_days: 30)
    subscriptions.where(status: [:pending, :active])
                 .where("start_date >= ? AND start_date <= ?", from, from + within_days)
                 .exists?
  end

  def delete_invoices
    invoices.each { |inv| inv.invoice_items.delete_all }
    invoices.delete_all
  end

  private

  # infer starter kit based on sub plan

  def determine_starter_kit_title
    case plan
    when "Standard"
      "Standard Starter Kit"
    when "XL"
      "XL Starter Kit"
    else
      puts "Invalid plan"
    end
  end

  # infer product title for first invoice based on subscription plan and duration

  def determine_subscription_title(duration, plan)
    case plan
    when "Standard"
      case duration
      when 1
        "Standard 1 month subscription"
      when 3
        "Standard 3 month subscription"
      when 6
        "Standard 6 month subscription"
      else
        puts "Invalid duration"
      end
    when "XL"
      case duration
      when 1
        "XL 1 month subscription"
      when 3
        "XL 3 month subscription"
      when 6
        "XL 6 month subscription"
      else
        puts "Invalid duration"
      end
    else
      puts "Invalid plan"
    end
  end

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
      update!(suburb: suburb)
      puts "found the sub in the list of subs"
    end
    nil
  end

  def canonicalize_suburb
    return if suburb.blank?
    self.suburb = LEGACY_TO_CANONICAL.fetch(suburb, suburb)
  end

  # def set_customer_id
  #   return if self.customer_id.present?
  #   customers = User.where(role: 'customer').where.not(customer_id: nil)
  #   last_id = (customers.sort_by { |customer| customer.customer_id[4..-1].to_i }.last&.customer_id || "")[4..-1].to_i
  #   new_customer_id = "GFWC" + (last_id + 1).to_s
  #   self.update!(customer_id: new_customer_id)
  #   self.user.update!(customer_id: new_customer_id) if self.user.customer_id.nil?
  # end

end
