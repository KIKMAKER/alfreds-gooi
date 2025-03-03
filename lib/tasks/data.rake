namespace :data do
  desc "Ensure users have a single active subscription with correct start date, collapsing old ones"

  task fix_active_subscriptions: :environment do
    input_file_path = Rails.root.join("lib", "assets", "subscription_dates.csv")

    ActiveRecord::Base.logger.silence do
      CSV.foreach(input_file_path, headers: true) do |row|
        customer_id = row["customer_id"]
        csv_start_date = Date.parse(row["start_date"])
        csv_duration = row["duration"].to_i

        user = User.find_by(customer_id: customer_id)
        unless user
          puts "No user found for customer_id #{customer_id}, skipping."
          next
        end

        subscriptions = user.subscriptions.order(:start_date)
        latest_sub = subscriptions.last

        # If they already have a sub matching the correct start_date, skip
        if latest_sub && latest_sub.start_date.to_date == csv_start_date && latest_sub.duration == csv_duration
          puts "✓ #{customer_id}: Subscription is already correct."
          next
        end

        # Step 1: Create a New Correct Subscription
        new_sub = user.subscriptions.create!(
          start_date: csv_start_date,
          duration: csv_duration,
          status: "active",
          is_new_customer: false
        )
        puts "✅ Created new active subscription for #{customer_id} (#{csv_start_date} - #{csv_duration} months)"

        # Step 2: Move all collections **from this date onward** to the new sub
        user.collections.where("date >= ?", csv_start_date).update_all(subscription_id: new_sub.id)

        # Step 3: Collapse Old Subscriptions into One "Legacy" Sub
        if subscriptions.any?
          legacy_sub = user.subscriptions.create!(
            start_date: subscriptions.minimum(:start_date), # Earliest known start date
            duration: subscriptions.sum(:duration), # Sum of all past durations
            status: "legacy",
            is_new_customer: false
          )
          puts "📜 Created Legacy Subscription for #{customer_id} covering all past subs."

          # Move all old collections to the legacy sub
          user.collections.where("date < ?", csv_start_date).update_all(subscription_id: legacy_sub.id)

          # Delete all other past subscriptions (except the new active & legacy ones)
          subscriptions.where.not(id: [new_sub.id, legacy_sub.id]).destroy_all
        end

        puts "🎉 #{customer_id}: Subscriptions cleaned up!"
      end
    end

    puts "🎯 All active subscriptions are now aligned with reality!"
  end
end
