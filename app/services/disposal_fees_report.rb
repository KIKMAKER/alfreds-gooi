# Summarises what Gooi owes each drop-off site for disposal, by month.
#
# Fees are charged per kilogram against the weight the driver recorded on the
# drop-off event, so there is no separate data-entry step: completed drops are
# the source of truth.
#
# Only charging sites appear — free sites (Soil for Life) sit at fee_per_kg 0
# and are excluded rather than listed with a zero owed.
class DisposalFeesReport
  Row = Struct.new(:site, :month, :kg_dropped, :fee_per_kg, :fee_owed, keyword_init: true) do
    def site_name = site.name
  end

  def initialize(sites: DropOffSite.charging)
    @sites = sites
  end

  # Newest month first, then site name.
  def rows
    @rows ||= begin
      totals = DropOffEvent.completed
                           .where(drop_off_site: @sites)
                           .where.not(date: nil)
                           .group(:drop_off_site_id, Arel.sql("DATE_TRUNC('month', drop_off_events.date)"))
                           .sum(:weight_kg)

      sites_by_id = @sites.index_by(&:id)

      totals.map { |(site_id, month), kg|
        site = sites_by_id[site_id]
        kg = kg.to_f.round(2)

        Row.new(
          site:       site,
          month:      month.to_date,
          kg_dropped: kg,
          fee_per_kg: site.fee_per_kg,
          fee_owed:   (kg * site.fee_per_kg.to_f).round(2)
        )
      }.sort_by { |row| [-row.month.to_time.to_i, row.site_name] }
    end
  end

  def total_owed
    rows.sum(&:fee_owed).round(2)
  end

  def owed_by_month
    rows.group_by(&:month).transform_values { |month_rows| month_rows.sum(&:fee_owed).round(2) }
  end
end
