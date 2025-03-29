#!/usr/bin/env ruby

require 'open3'

# === CONFIG ===
app_name = "alfreds-gooi" # <-- Change this
tables = %w[
  collections
  drivers_days
  subscriptions
  users
]

# === Get the Heroku DB URL ===
puts "Fetching DATABASE_URL for #{app_name}..."
db_url = `heroku config:get DATABASE_URL --app #{app_name}`.strip

if db_url.empty?
  puts "❌ Could not fetch DATABASE_URL. Is Heroku CLI logged in and the app name correct?"
  exit 1
end

# === Export each table ===
tables.each do |table|
  output_file = "#{table}.csv"
  puts "📦 Exporting #{table} to #{output_file}..."

  copy_cmd = "\\COPY #{table} TO '#{output_file}' CSV HEADER"

  # Run psql with the \COPY command
  stdout_str, stderr_str, status = Open3.capture3("psql", db_url, "-c", copy_cmd)

  if status.success?
    puts "✅ Exported #{output_file}"
  else
    puts "❌ Failed to export #{table}:"
    puts stderr_str
  end
end

puts "🎉 Done!"
