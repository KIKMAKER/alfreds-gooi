namespace :collections do
  desc "Reassign bags from donor to receiver week by week"
  task :reassign_bags, [:donor_customer_id, :receiver_customer_id, :mode] => :environment do |t, args|
    # Parse arguments
    donor_customer_id = args[:donor_customer_id]
    receiver_customer_id = args[:receiver_customer_id]
    mode = args[:mode] || 'dry_run' # 'dry_run' or 'live'

    # Validate arguments
    unless donor_customer_id && receiver_customer_id
      puts "Usage: rake collections:reassign_bags[donor_customer_id,receiver_customer_id,mode]"
      puts "Example: rake collections:reassign_bags[GFWC123,GFWC456,dry_run]"
      puts "Modes: dry_run (default), live"
      exit
    end

    # Find users by customer_id
    donor = User.find_by(customer_id: donor_customer_id)
    receiver = User.find_by(customer_id: receiver_customer_id)

    unless donor && receiver
      puts "❌ Could not find users:"
      puts "  Donor '#{donor_customer_id}': #{donor ? '✓ Found' : '✗ Not found'}"
      puts "  Receiver '#{receiver_customer_id}': #{receiver ? '✓ Found' : '✗ Not found'}"
      exit
    end

    puts "\n" + "="*80
    puts "BAG REASSIGNMENT #{mode.upcase == 'LIVE' ? '🔴 LIVE MODE' : '🔍 DRY RUN'}"
    puts "="*80
    puts "Donor: #{donor.full_name} (#{donor.customer_id})"
    puts "Receiver: #{receiver.full_name} (#{receiver.customer_id})"
    puts "Period: September 1, 2024 - #{Date.today.strftime('%B %d, %Y')}"
    puts "="*80
    puts ""

    # Date range
    start_date = Date.new(2024, 9, 1)
    end_date = Date.today

    # Statistics
    stats = {
      total_weeks: 0,
      transfers_made: 0,
      skipped_donor_insufficient: 0,
      skipped_missing_collections: 0,
      total_bags_transferred: 0
    }

    # Process week by week
    current_week_start = start_date.beginning_of_week

    while current_week_start <= end_date
      week_end = current_week_start.end_of_week
      stats[:total_weeks] += 1

      # Find collections for both users in this week
      donor_collection = donor.collections
                              .where(date: current_week_start..week_end)
                              .first

      receiver_collection = receiver.collections
                                    .where(date: current_week_start..week_end)
                                    .first

      # Check if both collections exist
      if donor_collection.nil? || receiver_collection.nil?
        stats[:skipped_missing_collections] += 1
        puts "Week #{current_week_start.strftime('%b %d')} - #{week_end.strftime('%b %d')}: ⊘ Skipped (missing collection)"
        current_week_start += 1.week
        next
      end

      # Check if donor has more than 1 bag
      if donor_collection.bags <= 1
        stats[:skipped_donor_insufficient] += 1
        puts "Week #{current_week_start.strftime('%b %d')} - #{week_end.strftime('%b %d')}: ⊘ Skipped (donor has #{donor_collection.bags} bag)"
        current_week_start += 1.week
        next
      end

      # Perform transfer
      if mode.downcase == 'live'
        ActiveRecord::Base.transaction do
          donor_collection.update!(bags: donor_collection.bags - 1)
          receiver_collection.update!(
            bags: receiver_collection.bags + 1,
            skip: false
          )
        end
      end

      stats[:transfers_made] += 1
      stats[:total_bags_transferred] += 1

      # Calculate before/after values
      donor_before = mode.downcase == 'live' ? donor_collection.bags + 1 : donor_collection.bags
      donor_after = mode.downcase == 'live' ? donor_collection.bags : donor_collection.bags - 1
      receiver_before = mode.downcase == 'live' ? receiver_collection.bags - 1 : receiver_collection.bags
      receiver_after = mode.downcase == 'live' ? receiver_collection.bags : receiver_collection.bags + 1
      receiver_skip_before = mode.downcase == 'live' ? true : receiver_collection.skip

      puts "Week #{current_week_start.strftime('%b %d')} - #{week_end.strftime('%b %d')}: ✓ #{mode.downcase == 'live' ? 'TRANSFERRED' : 'Would transfer'} 1 bag"
      puts "  Donor: #{donor_before} → #{donor_after} bags (#{donor_collection.date.strftime('%a %b %d')})"
      puts "  Receiver: #{receiver_before} → #{receiver_after} bags, skip: #{receiver_skip_before} → false (#{receiver_collection.date.strftime('%a %b %d')})"

      current_week_start += 1.week
    end

    # Print summary
    puts "\n" + "="*80
    puts "SUMMARY"
    puts "="*80
    puts "Total weeks processed: #{stats[:total_weeks]}"
    puts "Transfers #{mode.downcase == 'live' ? 'made' : 'that would be made'}: #{stats[:transfers_made]}"
    puts "Skipped (donor insufficient bags): #{stats[:skipped_donor_insufficient]}"
    puts "Skipped (missing collections): #{stats[:skipped_missing_collections]}"
    puts "Total bags #{mode.downcase == 'live' ? 'transferred' : 'to transfer'}: #{stats[:total_bags_transferred]}"

    if mode.downcase != 'live'
      puts "\n⚠️  This was a DRY RUN - no changes were made"
      puts "To execute: rake collections:reassign_bags['#{donor_customer_id}','#{receiver_customer_id}','live']"
    else
      puts "\n✅ Live run completed successfully"
    end
    puts "="*80
  end
end
