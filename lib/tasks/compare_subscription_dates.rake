namespace :data do
  desc "Compare subscription dates from CSV with the database (outputs to file locally, console on Heroku)"

  task compare_subscription_dates: :environment do
    input_file_path = Rails.root.join("lib", "assets", "subscription_dates.csv")

    # Determine output destination
    if Rails.env.production?
      output_stream = $stdout  # Heroku-friendly
    else
      output_file_path = Rails.root.join("tmp", "subscription_date_comparison.csv")
      output_stream = File.open(output_file_path, "w")
    end

    # Write CSV headers
    output_stream.puts "customer_id,csv_start_date,db_start_date,csv_duration,db_duration,status"

    ActiveRecord::Base.logger.silence do
      CSV.foreach(input_file_path, headers: true) do |row|
        customer_id = row['customer_id']
        csv_start_date = row['start_date']
        csv_duration = row['duration']

        user = User.find_by(customer_id: customer_id)

        if user.nil?
          output_stream.puts [customer_id, csv_start_date, nil, csv_duration, nil, "User not found"].to_csv
          next
        end

        latest_subscription = user.subscriptions.order(created_at: :desc).first

        if latest_subscription.nil?
          output_stream.puts [customer_id, csv_start_date, nil, csv_duration, nil, "No subscriptions found"].to_csv
          next
        end

        db_start_date = latest_subscription.start_date&.to_date
        db_duration = latest_subscription.duration

        status = if db_start_date.to_s == csv_start_date && db_duration.to_s == csv_duration
                   "MATCH"
                 else
                   "MISMATCH"
                 end

        output_stream.puts [customer_id, csv_start_date, db_start_date, csv_duration, db_duration, status].to_csv
      end
    end

    if !Rails.env.production?
      output_stream.close
      puts "Comparison complete. Results saved to: #{output_file_path}"
    end
  end
end
