namespace :geo do
  desc "Check suburb names against GeoJSON"
  task check: :environment do
    path = Rails.root.join("app/assets/geo/suburbs.geojson")
    data = JSON.parse(File.read(path))
    names = data["features"].map { |f| (f.dig("properties","name") || f.dig("properties","Name")).to_s.strip }.uniq

    {
      "Tuesday" => Subscription::TUESDAY_SUBURBS,
      "Wednesday" => Subscription::WEDNESDAY_SUBURBS,
      "Thursday" => Subscription::THURSDAY_SUBURBS
    }.each do |day, list|
      missing = list.reject { |s| names.include?(s) }
      puts "#{day} missing (#{missing.size}): #{missing.join(", ")}" if missing.any?
    end
  end
end
