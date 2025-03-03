namespace :data do
  desc "Sync old subscriptions from CSV, only if they don't match the database (updates duration if needed)"

  task sync_old_subscriptions: :environment do
    input_file_path = Rails.root.join("lib", "assets", "subscription_dates.csv")

    ActiveRecord::Base.logger.silence do
      CSV.foreach(input_file_path, headers: true) do |row|
        customer_id = row['customer_id']
        csv_start_date = Date.parse(row['start_date'])
        csv_duration = row['duration'].to_i

        user = User.find_by(customer_id: customer_id)

        unless user
          puts "No user found for customer_id #{customer_id}, skipping."
          next
        end

        latest_sub = user.subscriptions.order(created_at: :desc).first

        if latest_sub.nil?
          puts "❓ No subscription found for #{customer_id}, creating new one."
          create_new_subscription(user, csv_start_date, csv_duration)
          next
        end

        if latest_sub.start_date.to_date == csv_start_date
          if latest_sub.duration == csv_duration
            puts "✓ Subscription for #{customer_id} is already correct, skipping."
          else
            puts "🔄 Duration mismatch for #{customer_id}, updating duration to #{csv_duration} months."
            latest_sub.update!(duration: csv_duration)
          end
        else
          puts "⛔ MISMATCH for #{customer_id}, creating new subscription."
          create_new_subscription(user, csv_start_date, csv_duration)
        end
      end
    end

    puts "Old subscription sync completed!"
  end

  def create_new_subscription(user, start_date, duration)
    new_subscription = user.subscriptions.create!(
      start_date: start_date,
      duration: duration,
      status: 'active'
    )

    # Find the start date of the next subscription, if there is one.
    next_sub = user.subscriptions
                   .where('start_date > ?', start_date)
                   .order(:start_date)
                   .first

    # Find all collections within the date range belonging to this user
    collections_to_reassign = if next_sub
      user.collections.where('date >= ? AND date < ?', start_date, next_sub.start_date)
    else
      user.collections.where('date >= ?', start_date)
    end

    collections_to_reassign.update_all(subscription_id: new_subscription.id)

    puts "✅ New subscription created for #{user.customer_id} with start_date #{start_date} and duration #{duration} months."
    puts "🔄 Reassigned #{collections_to_reassign.count} collections to new subscription."
  end

end
