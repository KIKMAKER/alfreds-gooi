namespace :export do
  desc "Export selected tables to CSV and zip them"
  task csv: :environment do
    require 'fileutils'
    require 'zip'

    app_name = "alfreds-gooi" # ← change this!
    tables = %w[
      collections
      drivers_days
      subscriptions
      users
    ]

    export_dir = Rails.root.join("tmp", "csv_exports")
    zip_path = Rails.root.join("tmp", "csv_exports.zip")

    # Clean up any old files
    FileUtils.rm_rf(export_dir)
    FileUtils.rm_f(zip_path)
    FileUtils.mkdir_p(export_dir)

    puts "📦 Exporting tables from #{app_name}..."

    db_url = `heroku config:get DATABASE_URL --app #{app_name}`.strip

    if db_url.empty?
      puts "❌ Could not get DATABASE_URL from Heroku. Is the app name correct?"
      exit 1
    end

    tables.each do |table|
      csv_file_path = export_dir.join("#{table}.csv")
      copy_cmd = "\\COPY #{table} TO '#{csv_file_path}' CSV HEADER"
      puts "➡️  Exporting #{table}..."

      system("psql", db_url, "-c", copy_cmd) || puts("❌ Failed to export #{table}")
    end

    puts "🗜️  Zipping files..."

    Zip::File.open(zip_path, Zip::File::CREATE) do |zipfile|
      Dir[export_dir.join("*.csv")].each do |csv_file|
        zipfile.add(File.basename(csv_file), csv_file)
      end
    end

    puts "✅ Done! Zip file created at:"
    puts "👉 #{zip_path}"
  end
end
