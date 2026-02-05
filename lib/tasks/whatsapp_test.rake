# frozen_string_literal: true

namespace :whatsapp_test do
  desc "Create test data for WhatsApp reminders for all days of the week"
  task seed_week: :environment do
    puts "Creating WhatsApp test data for all weekdays..."
    puts "=" * 60

    # Map of days to test user data
    test_users = {
      0 => { # Sunday
        email: "test-sunday@example.com",
        first_name: "Sunday",
        phone: "+27785325513",
        suburb: "Observatory",  # Will manually set collection_day
        plan: "Standard"
      },
      1 => { # Monday
        email: "test-monday@example.com",
        first_name: "Monday",
        phone: "+27785325513",
        suburb: "Observatory",  # Monday suburb
        plan: "Standard"
      },
      2 => { # Tuesday
        email: "test-tuesday@example.com",
        first_name: "Tuesday",
        phone: "+27785325513",
        suburb: "Claremont",  # Tuesday suburb
        plan: "Standard"
      },
      3 => { # Wednesday
        email: "test-wednesday@example.com",
        first_name: "Wednesday",
        phone: "+27785325513",
        suburb: "Camps Bay",  # Wednesday suburb
        plan: "XL"
      },
      4 => { # Thursday
        email: "test-thursday@example.com",
        first_name: "Thursday",
        phone: "+27785325513",
        suburb: "Gardens",  # Thursday suburb
        plan: "Standard"
      },
      5 => { # Friday
        email: "test-friday@example.com",
        first_name: "Friday",
        phone: "+27785325513",
        suburb: "Tamboerskloof",  # Thursday suburb (no Friday-specific)
        plan: "XL"
      },
      6 => { # Saturday
        email: "test-saturday@example.com",
        first_name: "Saturday",
        phone: "+27785325513",
        suburb: "Claremont",  # Will manually set collection_day
        plan: "XL"
      }
    }

    created_count = 0
    skipped_count = 0

    test_users.each do |day_num, data|
      # Check if user already exists
      user = User.find_by(email: data[:email])

      if user
        puts "⚠  User #{data[:email]} already exists, updating..."
        user.update!(
          phone_number: data[:phone],
          whatsapp_opt_out: false
        )
      else
        user = User.create!(
          email: data[:email],
          first_name: data[:first_name],
          last_name: "Test",
          phone_number: data[:phone],
          password: "password",
          role: "customer",
          whatsapp_opt_out: false
        )
        puts "✓ Created user: #{user.email}"
      end

      # Check if subscription exists
      subscription = user.subscriptions.active.first

      if subscription
        puts "⚠  Active subscription already exists for #{user.email}"
        skipped_count += 1
      else
        subscription = Subscription.create!(
          user: user,
          street_address: "123 Test Street, #{data[:suburb]}, Cape Town, 8001, South Africa",
          suburb: data[:suburb],
          plan: data[:plan],
          status: :active,
          duration: 6,
          start_date: 1.month.ago,
          collection_order: 1
        )

        # Manually set collection_day for weekend users (bypass suburb auto-assignment)
        if day_num == 0 || day_num == 6
          subscription.update_column(:collection_day, day_num)
          subscription.reload
        end

        puts "✓ Created subscription: #{subscription.plan} in #{subscription.suburb} (#{subscription.collection_day})"
      end

      # Create collection for tomorrow
      tomorrow = Date.tomorrow

      # Check if collection already exists for tomorrow
      existing_collection = subscription.collections.find_by(date: tomorrow)

      if existing_collection
        puts "⚠  Collection for tomorrow already exists for #{user.email}"
        skipped_count += 1
      else
        collection = Collection.create!(
          subscription: subscription,
          date: tomorrow,
          skip: false,
          is_done: false,
          bags: subscription.plan == "Standard" ? rand(1..3) : 0,
          buckets: subscription.plan == "XL" ? rand(1..2) : 0
        )
        puts "✓ Created collection for #{tomorrow.strftime('%A, %B %d')}"
        created_count += 1
      end

      puts ""
    end

    puts "=" * 60
    puts "WhatsApp test data setup complete!"
    puts "  Created: #{created_count} collections"
    puts "  Skipped: #{skipped_count} (already existed)"
    puts ""
    puts "Test users created:"
    test_users.each do |day_num, data|
      puts "  - #{data[:email]} (#{data[:phone]}) - #{Date::DAYNAMES[day_num]}"
    end
    puts ""
    puts "To test WhatsApp reminders:"
    puts "  1. Update your .env with real Twilio credentials"
    puts "  2. Join Twilio sandbox: Send 'join <code>' to +1 415 523 8886"
    puts "  3. Test send: rails whatsapp:test_reminder[test-tuesday@example.com]"
    puts "  4. Click 'skip me' button in WhatsApp to test webhook"
    puts ""
    puts "Tomorrow is #{Date::DAYNAMES[Date.tomorrow.wday]}, so test with:"
    tomorrow_user = test_users.find { |day, _| day == Date.tomorrow.wday }
    if tomorrow_user
      puts "  rails whatsapp:test_reminder[#{tomorrow_user[1][:email]}]"
    else
      puts "  (No test user for tomorrow's day - run on a weekday)"
    end
    puts "=" * 60
  end

  desc "Show WhatsApp test status"
  task status: :environment do
    puts "WhatsApp Test Data Status"
    puts "=" * 60
    puts "Tomorrow is: #{Date.tomorrow.strftime('%A, %B %d, %Y')}"
    puts ""

    test_emails = [
      "test-sunday@example.com",
      "test-monday@example.com",
      "test-tuesday@example.com",
      "test-wednesday@example.com",
      "test-thursday@example.com",
      "test-friday@example.com",
      "test-saturday@example.com"
    ]

    test_emails.each do |email|
      user = User.find_by(email: email)
      if user
        subscription = user.subscriptions.active.first
        collection = user.collections.where(date: Date.tomorrow).first

        puts "#{user.first_name} (#{email}):"
        puts "  Phone: #{user.phone_number}"
        puts "  Can receive WhatsApp: #{user.can_receive_whatsapp?}"
        puts "  Subscription: #{subscription ? "#{subscription.plan} (#{subscription.collection_day})" : "None"}"
        puts "  Collection tomorrow: #{collection ? "Yes (skip=#{collection.skip}, done=#{collection.is_done})" : "No"}"
        puts ""
      else
        puts "#{email}: Not found"
        puts ""
      end
    end

    puts "=" * 60
  end

  desc "Clean up WhatsApp test data"
  task cleanup: :environment do
    puts "Cleaning up WhatsApp test data..."

    test_emails = [
      "test-sunday@example.com",
      "test-monday@example.com",
      "test-tuesday@example.com",
      "test-wednesday@example.com",
      "test-thursday@example.com",
      "test-friday@example.com",
      "test-saturday@example.com"
    ]

    test_emails.each do |email|
      user = User.find_by(email: email)
      if user
        # Delete associated data in correct order
        user.whatsapp_messages.destroy_all
        # Delete collections through subscriptions (can't destroy_all on has_many :through)
        user.subscriptions.each do |subscription|
          subscription.collections.destroy_all
        end
        user.subscriptions.destroy_all
        user.destroy
        puts "✓ Deleted user: #{email}"
      end
    end

    puts "Cleanup complete!"
  end
end
