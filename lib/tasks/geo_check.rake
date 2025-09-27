# lib/tasks/geo_check.rake
namespace :geo do
  desc "Check suburb names against GeoJSON"
  task check: :environment do
    require "json"

    path = Rails.root.join("app/assets/geo/Suburbs.geojson")
    data = JSON.parse(File.read(path))
    feats = data["features"] || []

    abort "No features in #{path}" if feats.empty?
    abort "Features have no properties" unless feats.first.key?("properties")

    # City file uses OFC_SBRB_NAME for the official name
    NAME_KEYS = ["OFC_SBRB_NAME", "OS Name", "OS_NAME", "NAME", "Name", "name"]

    name_key = (NAME_KEYS & feats.first["properties"].keys).first
    abort "Couldn't find a suburb name key in properties. Present keys: #{feats.first['properties'].keys.inspect}" unless name_key

    def norm(s)
      s.to_s.upcase
        .tr("’'", "")                 # Devil’s/Devil's → DEVILS
        .gsub(/\s*\(.*?\)\s*/, " ")   # strip (District Six), etc.
        .gsub(/\bUPPER\s+|LOWER\s+/, "")
        .gsub(/[\/\-_]/, " ")         # <— include "/" here
        .gsub(/\s+/, " ")
        .strip
    end

    dataset_names = feats.map { |f| norm(f["properties"][name_key]) }.uniq



    # Known aliases → official equivalents (after norm)
    ALIASES = {
      "SCHOTSCHE KLOOF"                 => "BO KAAP",
      "CAPE TOWN"                       => "CAPE TOWN CITY CENTRE",
      "WOODSTOCK INCLUDING UPPER WOODSTOCK" => "WOODSTOCK",
      "WALMER ESTATE DISTRICT SIX"      => "DISTRICT SIX",
      "ZONNEBLOEM DISTRICT SIX"         => "DISTRICT SIX",
      "MARINA DA GAMA"                  => "MUIZENBERG",
      "BAKOVEN"                         => "CAMPS BAY/BAKOVEN",
      "CAMPS BAY"                       => "CAMPS BAY/BAKOVEN",
      "DE WATERKANT"                    => "GREEN POINT",

      # These are “brand”/neighbourhood names inside the official suburb
      "HARFIELD VILLAGE"                => "CLAREMONT",
      "WITTEBOOMEN"                     => "CONSTANTIA",
      "LOWER VREDE DISTRICT SIX"   => "DISTRICT SIX",
      "UNIVERSITY ESTATE"      => "DISTRICT SIX",
      "HIGGOVALE"              => "ORANJEZICHT",
      "DEVIL'S PEAK ESTATE"    => "VREDEHOEK"
    }


    lists = {
      "Tuesday"   => Subscription::TUESDAY_SUBURBS,
      "Wednesday" => Subscription::WEDNESDAY_SUBURBS,
      "Thursday"  => Subscription::THURSDAY_SUBURBS
    }

    lists.each do |day, list|
      missing = list.reject do |raw|
        n = norm(raw)
        n = norm(ALIASES[n] || n)
        dataset_names.include?(n)
      end
      if missing.any?
        puts "#{day} missing (#{missing.size}): #{missing.join(', ')}"
      else
        puts "#{day}: all matched ✔"
      end
    end

    probes = [
      "MUIZENBERG", "SOUTH FIELD", "SOUTHFIELD",
      "BO KAAP", "SCHOTSCHE KLOOF",
      "DE WATERKANT", "HIGGOVALE", "UNIVERSITY ESTATE",
      "WALMER ESTATE", "ZONNEBLOEM", "DISTRICT SIX",
      "CAMPS BAY/BAKOVEN", "CAMPS BAY", "BAKOVEN",
      "CAPE TOWN", "CAPE TOWN CITY CENTRE",
      "DEVIL S PEAK ESTATE", "DEVILS PEAK ESTATE"
    ]
    probes.each { |p| puts "HAS #{p}? #{dataset_names.include?(norm(p))}" }
  end
end
