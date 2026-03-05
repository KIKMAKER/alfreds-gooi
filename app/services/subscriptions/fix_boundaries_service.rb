class Subscriptions::FixBoundariesService
  Result = Struct.new(:success, :changes, :error, keyword_init: true) do
    def success? = success
  end

  def initialize(user:, dry_run: false)
    @user = user
    @dry_run = dry_run
  end

  def call
    completed_subs_array = @user.subscriptions.where(status: :completed).order(:start_date).to_a
    return Result.new(success: false, error: "No completed subscriptions") if completed_subs_array.none?

    legacy_sub_ids = @user.subscriptions.where(status: :legacy).pluck(:id)

    effective_starts = {}
    changes = []

    completed_subs_array.each do |sub|
      effective_start = effective_starts[sub.id] || sub.start_date
      next unless effective_start && sub.duration

      n = (sub.duration * 4.2).ceil
      all_from_start = @user.collections
                            .where.not(subscription_id: legacy_sub_ids)
                            .where("date >= ?", effective_start)
                            .order(date: :asc)

      unskipped = all_from_start.where(skip: false).to_a
      nth_collection = unskipped[n - 1]
      next unless nth_collection

      new_end_date = nth_collection.date + 1.day
      in_range = all_from_start.where("date <= ?", nth_collection.date)
      in_range_count = in_range.count

      next_sub = completed_subs_array[completed_subs_array.index(sub) + 1] ||
                 @user.subscriptions.where(status: [:pending, :active, :pause]).order(:start_date).first
      next_collection_after = @user.collections
                                   .where.not(subscription_id: legacy_sub_ids)
                                   .where("date >= ?", new_end_date)
                                   .order(date: :asc)
                                   .first

      effective_starts[next_sub.id] = next_collection_after.date if next_sub && next_collection_after

      changes << {
        subscription_id: sub.id,
        start_date: effective_start,
        new_end_date: new_end_date,
        n: n,
        skipped_in_range: in_range_count - n,
        reassigning: in_range_count,
        next_sub_id: next_sub&.id,
        next_sub_new_start_date: next_collection_after&.date
      }

      unless @dry_run
        sub.update_column(:end_date, new_end_date)
        in_range.update_all(subscription_id: sub.id)
        next_sub.update_column(:start_date, next_collection_after.date) if next_sub && next_collection_after
      end
    end

    Result.new(success: true, changes: changes)
  end
end
