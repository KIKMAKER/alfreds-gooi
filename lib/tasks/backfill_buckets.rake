# lib/tasks/backfill_buckets.rake
namespace :data do
  desc "Backfill missing bucket counts on DriversDay records using bags-per-bucket ratio"
  task backfill_driver_day_buckets: :environment do
    puts "\n========================================="
    puts "DriversDay Bucket Backfill Task"
    puts "=========================================\n"

    execute_mode = ENV['EXECUTE'] == 'true'
    mode_label = execute_mode ? "EXECUTE MODE" : "DRY RUN MODE"
    puts "Running in: #{mode_label}\n\n"

    # Step 1: Calculate average bags-per-bucket ratio from valid data
    puts "Step 1: Calculating bags-per-bucket ratio from valid DriversDay records..."
    puts "-" * 60

    valid_days = DriversDay.where("total_buckets > 0")
    ratios = []

    valid_days.each do |dd|
      # Get Standard subscription bags for this day
      standard_bags = dd.collections
                        .joins(:subscription)
                        .where(subscriptions: { plan: 'Standard' })
                        .sum(:bags)

      # Get XL subscription buckets for this day
      xl_buckets = dd.collections
                     .joins(:subscription)
                     .where(subscriptions: { plan: 'XL' })
                     .count # Each XL collection = 1 full bucket

      # Calculate bag buckets (physical buckets that held bags)
      bag_buckets = dd.total_buckets - xl_buckets

      # Only use this day if we have valid data for ratio calculation
      if bag_buckets > 0 && standard_bags > 0
        ratio = standard_bags.to_f / bag_buckets
        ratios << ratio
        puts "  Day ##{dd.id} (#{dd.date}): #{standard_bags} bags in #{bag_buckets} buckets = #{ratio.round(2)} bags/bucket"
      end
    end

    if ratios.empty?
      puts "\n❌ ERROR: No valid days found with both bags and buckets data."
      puts "Cannot calculate ratio. Exiting."
      exit
    end

    average_ratio = ratios.sum / ratios.count
    puts "\n📊 RESULTS:"
    puts "  Valid sample days: #{ratios.count}"
    puts "  Calculated ratios: #{ratios.map { |r| r.round(2) }.join(', ')}"
    puts "  Average bags-per-bucket ratio: #{average_ratio.round(2)}"

    # Step 2: Find and backfill days with missing bucket data
    puts "\n\nStep 2: Finding DriversDay records with missing bucket data..."
    puts "-" * 60

    days_needing_backfill = DriversDay.where("total_buckets IS NULL OR total_buckets = 0")
                                      .where("id IN (SELECT DISTINCT drivers_day_id FROM collections WHERE drivers_day_id IS NOT NULL)")

    puts "Found #{days_needing_backfill.count} days needing backfill\n\n"

    updated_count = 0
    skipped_count = 0

    days_needing_backfill.each do |dd|
      # Get Standard subscription bags
      standard_bags = dd.collections
                        .joins(:subscription)
                        .where(subscriptions: { plan: 'Standard' })
                        .sum(:bags)

      # Get XL subscription buckets
      xl_buckets = dd.collections
                     .joins(:subscription)
                     .where(subscriptions: { plan: 'XL' })
                     .count

      # Skip if no data
      if standard_bags == 0 && xl_buckets == 0
        puts "  Day ##{dd.id} (#{dd.date}): SKIPPED - no collection data"
        skipped_count += 1
        next
      end

      # Estimate bag buckets using average ratio
      estimated_bag_buckets = if standard_bags > 0
                                (standard_bags / average_ratio).round
                              else
                                0
                              end

      # Calculate total estimated buckets
      estimated_total_buckets = estimated_bag_buckets + xl_buckets

      puts "  Day ##{dd.id} (#{dd.date}):"
      puts "    Standard bags: #{standard_bags}, XL buckets: #{xl_buckets}"
      puts "    Estimated bag buckets: #{estimated_bag_buckets} (#{standard_bags} / #{average_ratio.round(2)})"
      puts "    Total estimated buckets: #{estimated_total_buckets} (#{estimated_bag_buckets} + #{xl_buckets})"

      if execute_mode
        dd.update_column(:total_buckets, estimated_total_buckets)
        puts "    ✅ UPDATED"
        updated_count += 1
      else
        puts "    [DRY RUN - not updated]"
      end
      puts
    end

    # Step 3: Summary
    puts "\n========================================="
    puts "SUMMARY"
    puts "=========================================\n"
    puts "Valid sample days used: #{ratios.count}"
    puts "Average ratio: #{average_ratio.round(2)} bags per bucket"
    puts "Days needing backfill: #{days_needing_backfill.count}"
    puts "Days skipped (no data): #{skipped_count}"

    if execute_mode
      puts "Days updated: #{updated_count}"
      puts "\n✅ Backfill complete!"
    else
      puts "Days that would be updated: #{days_needing_backfill.count - skipped_count}"
      puts "\n💡 This was a DRY RUN. No changes were made."
      puts "To actually update the records, run: rails data:backfill_driver_day_buckets EXECUTE=true"
    end
    puts "=========================================\n\n"
  end
end
