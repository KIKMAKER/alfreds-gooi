class Subscriptions::FixBoundariesService
  Result = Struct.new(:success, :changes, :error, keyword_init: true)

  def initialize(user:, dry_run: false)
    @user = user
    @dry_run = dry_run
  end

  def call
    completed_subs_array = @user.subscriptions.where(status: :completed).order(:start_date).to_a
    return Result.new(success: false, error: "No completed subscriptions") if completed_subs_array.none?

    changes = []
    completed_subs_array.each do |sub|
      next unless sub.start_date && sub.duration

      n = (sub.duration * 4.2).ceil
      all_from_start = @user.collections
                            .where("date >= ?", sub.start_date)
                            .order(date: :asc)

      unskipped = all_from_start.where(skip: false).to_a
      nth_collection = unskipped[n - 1]
      next unless nth_collection

      new_end_date = nth_collection.date + 1.day
      in_range = all_from_start.where("date <= ?", nth_collection.date)

      next_sub = completed_subs_array[completed_subs_array.index(sub) + 1] ||
                 @user.subscriptions.where.not(status: :completed).order(:start_date).first
      next_collection_after = @user.collections
                                   .where("date >= ?", new_end_date)
                                   .order(date: :asc)
                                   .first

      changes << {
        subscription_id: sub.id,
        start_date: sub.start_date,
        new_end_date: new_end_date,
        n: n,
        unskipped_found: unskipped.length,
        reassigning: in_range.count,
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
