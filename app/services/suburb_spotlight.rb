# frozen_string_literal: true
class SuburbSpotlight
  Result = Struct.new(:suburb, :month_label, :kg_collected, :household_count, :collection_day)

  # No per-suburb kg is ever measured on a scale (buckets are only weighed at the
  # drivers_day level, with no link back to a subscription/suburb). We estimate it
  # the same way Block#weight_kg already does: collection volume (litres) x density.
  def self.call(suburb:, month: Date.current)
    suburb_record = Suburb.find_by(name: suburb)
    raise ArgumentError, "invalid suburb" unless suburb_record

    range = month.beginning_of_month..month.end_of_month
    collections = Collection.joins(:subscription)
                             .where(subscriptions: { suburb_id: suburb_record.id })
                             .where(date: range, skip: false)

    litres = collections.to_a.sum(&:volume_litres)
    kg_collected = (litres * Block::DENSITY_KG_PER_L).round
    household_count = collections.distinct.count(:subscription_id)

    Result.new(suburb, month.strftime("%B %Y"), kg_collected, household_count, suburb_record.collection_day)
  end
end
