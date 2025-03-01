namespace :data do
  desc "Compare subscription dates from CSV with the database"

  task compare_subscription_dates: :environment do
    input_file_path = Rails.root.join("lib", "assets", "subscription_dates.csv")
    output_file_path = Rails.root.join("lib", "assets", "subscription_comparison.csv")

    CSV.open(output_file_path, 'w') do |csv|
      # Write header row
      csv << ["customer_id", "csv_start_date", "db_start_date", "csv_duration", "db_duration", "status"]

      # Read input file
      CSV.foreach(input_file_path, headers: true) do |row|
        customer_id = row['customer_id']
        csv_start_date = row['start_date']
        csv_duration = row['duration']

        user = User.find_by(customer_id: customer_id)

        if user.nil?
          csv << [customer_id, csv_start_date, nil, csv_duration, nil, "User not found"]
          next
        end

        latest_subscription = user.subscriptions.order(created_at: :desc).first

        if latest_subscription.nil?
          csv << [customer_id, csv_start_date, nil, csv_duration, nil, "No subscriptions found"]
          next
        end

        db_start_date = latest_subscription.start_date&.to_date
        db_duration = latest_subscription.duration

        status = if db_start_date.to_s == csv_start_date && db_duration.to_s == csv_duration
                   "MATCH"
                 else
                   "MISMATCH"
                 end

        csv << [customer_id, csv_start_date, db_start_date, csv_duration, db_duration, status]
      end
    end

    puts "✅ Comparison complete! Check the file at: #{output_file_path}"
  end
end
