# Turns a festival's waste logs into the "cute facts" shown on its public
# impact page. FACTS is the menu the admin picks from (order = display order);
# #facts returns only the chosen ones that actually have something to say.
class FestivalImpact
  Fact = Struct.new(:key, :icon, :value, :unit, :label, :items, keyword_init: true) do
    def counts_up?
      items.blank? && value == value.round
    end
  end

  FACTS = {
    "organics"        => "Organics diverted from landfill (kg)",
    "to_pigs"         => "Scraps fed to pigs (kg)",
    "to_compost"      => "Scraps composted (kg)",
    "co2e"            => "CO₂e avoided (kg)",
    "car_km"          => "...as km driven in a car",
    "phone_charges"   => "...as smartphone charges",
    "trees"           => "...as trees absorbing for a year",
    "recycled"        => "Recycled: plastic, glass, tin, paper (kg)",
    "diversion_rate"  => "Share of waste kept out of landfill (%)",
    "grand_total"     => "Total waste tracked (kg)",
    "landfill"        => "Went to landfill (kg)",
    "source_split"    => "Vendors vs attendees (organics)",
    "daily"           => "Day-by-day totals"
  }.freeze

  def initialize(event)
    @event = event
    @logs  = event.festival_waste_logs
  end

  def facts(keys = @event.visible_facts)
    FACTS.keys.select { |k| keys.include?(k) }.filter_map { |k| build(k) }
  end

  def organics_kg
    @organics_kg ||= by_category.fetch("organic", 0.0)
  end

  def co2e_kg
    organics_kg * IMPACT[:co2e_per_kg_diverted]
  end

  def grand_total_kg
    by_category.values.sum
  end

  private

  def by_category
    @by_category ||= @logs.group(:category).sum(:weight_kg).transform_values(&:to_f)
  end

  def organic_to(destination)
    @logs.organic.where(destination: destination).sum(:weight_kg).to_f
  end

  def recycled_kg
    by_category.values_at(*(FestivalWasteLog::CHANEL_CATEGORIES - ["landfill"])).compact.sum
  end

  def landfill_kg
    by_category.fetch("landfill", 0.0)
  end

  def build(key)
    case key
    when "organics"       then fact(key, "🍌", organics_kg, "kg", "of food scraps and organics kept out of landfill")
    when "to_pigs"        then fact(key, "🐷", organic_to(:pigs), "kg", "of scraps fed to very happy pigs")
    when "to_compost"     then fact(key, "🌱", organic_to(:compost), "kg", "of scraps turned into compost")
    when "co2e"           then fact(key, "🌍", co2e_kg, "kg", "of CO₂e emissions avoided")
    when "car_km"         then fact(key, "🚗", co2e_kg / IMPACT[:car_co2e_per_km], "km", "of driving. That's the emissions we avoided")
    when "phone_charges"  then fact(key, "📱", co2e_kg / IMPACT[:phone_charge_co2e], nil, "smartphone charges' worth of emissions avoided")
    when "trees"          then fact(key, "🌳", co2e_kg / IMPACT[:tree_co2e_per_year], nil, "trees working for a whole year to absorb the same")
    when "recycled"       then fact(key, "♻️", recycled_kg, "kg", "of plastic, glass, tin and paper sent for recycling")
    when "grand_total"    then fact(key, "⚖️", grand_total_kg, "kg", "of festival waste weighed and sorted")
    when "landfill"       then fact(key, "🗑️", landfill_kg, "kg", "was all that went to landfill")
    when "diversion_rate" then diversion_rate_fact(key)
    when "source_split"   then source_split_fact(key)
    when "daily"          then daily_fact(key)
    end
  end

  def fact(key, icon, value, unit, label, items: nil)
    return if value.to_f <= 0 && items.blank?

    Fact.new(key: key, icon: icon, value: value.to_f.round(1), unit: unit, label: label, items: items)
  end

  def diversion_rate_fact(key)
    return if grand_total_kg <= 0

    pct = (grand_total_kg - landfill_kg) / grand_total_kg * 100
    fact(key, "💚", pct, "%", "of everything we weighed stayed out of landfill")
  end

  def source_split_fact(key)
    split = FestivalWasteLog.sources.keys.index_with { |s| @logs.organic.where(source: s).sum(:weight_kg).to_f }
    return if split.values.sum <= 0

    items = split.map { |s, kg| ["#{s.humanize.pluralize}", kg] }
    fact(key, "🎪", split.values.sum, "kg", "of organics, by who made them", items: items)
  end

  def daily_fact(key)
    totals = @logs.group(:day_number).sum(:weight_kg)
    return if totals.empty?

    items = totals.sort.map { |day, kg| [@event.day_label(day), kg.to_f] }
    fact(key, "📅", totals.values.sum.to_f, "kg", "day by day", items: items)
  end
end
