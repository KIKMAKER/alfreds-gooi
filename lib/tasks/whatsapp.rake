# frozen_string_literal: true

namespace :whatsapp do
  desc "Send collection reminders for tomorrow"
  task send_reminders: :environment do
    puts "Starting WhatsApp reminder job for tomorrow..."
    WhatsappReminderJob.perform_now
    puts "✓ WhatsApp reminders queued"
  end

  desc "Test WhatsApp reminder for specific user"
  task :test_reminder, [:email] => :environment do |_t, args|
    unless args[:email]
      puts "Usage: rails whatsapp:test_reminder[user@example.com]"
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit 1
    end

    subscription = user.subscriptions.active.first
    unless subscription
      puts "No active subscription for #{args[:email]}"
      exit 1
    end

    unless user.can_receive_whatsapp?
      puts "User cannot receive WhatsApp: #{user.phone_number.blank? ? 'no phone' : 'opted out'}"
      exit 1
    end

    puts "Sending test reminder to #{user.email} (#{user.phone_number})..."
    puts "Collection date: #{Date.tomorrow}"
    puts "Subscription: #{subscription.plan}"
    puts ""

    # Ask if user wants template or freeform
    print "Use template with skip button? (Y/n): "
    use_template_input = STDIN.gets.chomp
    use_template = use_template_input.downcase != 'n'

    service = TwilioWhatsappService.new
    result = service.send_collection_reminder(
      user: user,
      subscription: subscription,
      collection_date: Date.tomorrow,
      use_template: use_template
    )

    if result.failed?
      puts "✗ Failed to send: #{result.error_message}"
    else
      puts "✓ Test message sent to #{user.phone_number}"
      puts "  Type: #{result.used_template ? 'Template (with skip button)' : 'Freeform'}"
      puts "  Twilio SID: #{result.twilio_sid}"
      puts "  Status: #{result.status}"
    end
  end

  desc "Show WhatsApp stats"
  task stats: :environment do
    eligible = User.joins(:subscriptions)
                  .where(subscriptions: { status: :active })
                  .where.not(phone_number: nil)
                  .where(whatsapp_opt_out: false)
                  .distinct
                  .count

    no_phone = User.joins(:subscriptions)
                  .where(subscriptions: { status: :active })
                  .where(phone_number: nil)
                  .distinct
                  .count

    opted_out = User.where(whatsapp_opt_out: true).count

    puts "WhatsApp Reminder Stats"
    puts "=" * 60
    puts "Eligible for reminders: #{eligible}"
    puts "Missing phone numbers: #{no_phone}"
    puts "Opted out: #{opted_out}"
    puts ""
    puts "Messages sent (all time): #{WhatsappMessage.count}"
    puts "  - Delivered: #{WhatsappMessage.delivered.count}"
    puts "  - Failed: #{WhatsappMessage.failed.count}"
    puts "  - Using template: #{WhatsappMessage.where(used_template: true).count}"
    puts "  - Freeform: #{WhatsappMessage.where(used_template: false).count}"
    puts "=" * 60
  end
end
