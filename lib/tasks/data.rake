namespace :data do
  desc "Fix active subscriptions by creating a new subscription if necessary and collapsing old subscriptions into a legacy subscription"

  task fix_active_subscriptions: :environment do
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
        puts "found #{user.first_name} with customer id #{user.customer_id}"

        subscriptions = user.subscriptions.order(start_date: :asc)
        latest_sub = subscriptions.last

        # Sanity check — if the latest sub already matches, skip this user.
        if latest_sub && latest_sub.start_date == csv_start_date && latest_sub.duration == csv_duration
          puts "✓ #{customer_id}: Subscription is already correct."
          next
        end

        # Step 1: Create New Subscription with Latest Data
        new_sub = user.subscriptions.create!(
          customer_id: user.customer_id,
          start_date: csv_start_date,
          duration: csv_duration,
          status: "active",
          is_new_customer: false,
          # Copy address & location details from the latest subscription (assumes the latest is the most accurate)
          street_address: latest_sub.street_address,
          suburb: latest_sub.suburb,
          apartment_unit_number: latest_sub.apartment_unit_number,
          collection_order: latest_sub.collection_order,
          collection_day: latest_sub.collection_day,
          latitude: latest_sub.latitude,
          longitude: latest_sub.longitude,
          plan: latest_sub.plan
          # referral_code: latest_sub.referral_code
        )
        puts "🆕 Created New Subscription for #{customer_id} starting #{new_sub.start_date.strftime('%m-%d-%Y')} based on csv date: #{csv_start_date}"

        # Step 2: Reassign Collections to New Subscription
        user.collections.where("date >= ?", csv_start_date).update_all(subscription_id: new_sub.id)
        user.collections.where("date >= ?", latest_sub.start_date).update_all(subscription_id: latest_sub.id)
        puts "🔄 Reassigned recent collections to new sub #{new_sub.id}"

        # Step 3: Collapse Old Subscriptions into One "Legacy" Subscription
        if subscriptions.any?
          legacy_sub = user.subscriptions.create!(
            customer_id: user.customer_id,
            start_date: subscriptions.minimum(:start_date), # Earliest known start date
            duration: subscriptions.sum(:duration), # Sum of all past durations
            status: "legacy",
            is_new_customer: false,
            # Preserve address & other details from the latest subscription (or first subscription if you'd prefer)
            street_address: latest_sub.street_address,
            suburb: latest_sub.suburb,
            apartment_unit_number: latest_sub.apartment_unit_number,
            collection_order: latest_sub.collection_order,
            collection_day: latest_sub.collection_day,
            latitude: latest_sub.latitude,
            longitude: latest_sub.longitude,
            plan: latest_sub.plan
            # referral_code: latest_sub.referral_code
          )
          puts "📜 Created Legacy Subscription for #{customer_id} covering all past subs."

          # Move all old collections to the legacy subscription
          puts "🔄 Moving all past collections to legacy sub #{legacy_sub.id}"
          user.collections.where("date < ?", csv_start_date).update_all(subscription_id: legacy_sub.id)

          # user = User.find_by(first_name: "Lulu")
          # subscription = user.subscriptions.where(status: "active").first
          # subscription.update(start_date: Date.new(2025, 01, 15))

          # user.collections.where("date > ?", subscription.start_date).count
          # user.collections.where("date > ?", subscription.start_date).update_all(subscription_id: subscription.id)

          # Reassign all invoices from old subs to the new sub
          subscriptions.where.not(id: [new_sub.id, legacy_sub.id]).each do |old_sub|
            old_sub.invoices.update_all(subscription_id: new_sub.id)
          end

          # Destroy the old subscriptions (except new & legacy)
          subscriptions.where.not(id: [new_sub.id, legacy_sub.id]).destroy_all
        end

        puts "🎉 #{customer_id}: Subscriptions cleaned up!"
      end
    end

    puts "✅ Active subscription cleanup completed!"
  end
end
