namespace :suburbs do
  desc "Preview how legacy suburb names will be migrated"
  task preview: :environment do
    allowed  = Subscription::SUBURBS
    mapping  = Subscription::LEGACY_TO_CANONICAL
    counts   = Subscription.group(:suburb).count

    out_of_set = counts.keys - allowed
    puts "Out-of-set values (#{out_of_set.size}):"
    out_of_set.each do |name|
      target = mapping[name]
      puts "  #{name.ljust(28)} #{counts[name]}  ->  #{target || 'NO MAPPING!'}"
    end
  end

  desc "Migrate legacy suburb names to canonical values"
  task migrate: :environment do
    mapping = Subscription::LEGACY_TO_CANONICAL
    Subscription.transaction do
      mapping.each do |from, to|
        scope = Subscription.where(suburb: from)
        next if scope.empty?
        puts "Updating #{scope.count} rows: #{from} -> #{to}"
        scope.update_all(suburb: to, updated_at: Time.current) # skips validations
      end
    end
    puts "Done."
  end
end
