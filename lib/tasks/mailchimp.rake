# frozen_string_literal: true

namespace :mailchimp do
  desc "Sync all users with subscriptions to Mailchimp"
  task sync_all: :environment do
    puts "Starting Mailchimp sync for all users..."
    puts "=" * 60

    results = MailchimpSyncService.sync_all_users

    puts "\nSync Complete!"
    puts "  ✓ Successfully synced: #{results[:synced]}"
    puts "  ✗ Failed: #{results[:failed]}"

    if results[:errors].any?
      puts "\nErrors:"
      results[:errors].each do |error|
        puts "  - User #{error[:user_id]} (#{error[:email]}): #{error[:error]}"
      end
    end

    puts "=" * 60
  end

  desc "Sync a specific user by email to Mailchimp"
  task :sync_user, [:email] => :environment do |_t, args|
    unless args[:email]
      puts "Usage: rails mailchimp:sync_user[user@example.com]"
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit 1
    end

    puts "Syncing #{user.email} to Mailchimp..."
    if MailchimpSyncService.sync_user(user)
      puts "✓ Successfully synced #{user.email}"
    else
      puts "✗ Failed to sync #{user.email}"
      exit 1
    end
  end

  desc "Remove a user from Mailchimp by email"
  task :remove_user, [:email] => :environment do |_t, args|
    unless args[:email]
      puts "Usage: rails mailchimp:remove_user[user@example.com]"
      exit 1
    end

    user = User.find_by(email: args[:email])
    unless user
      puts "User not found: #{args[:email]}"
      exit 1
    end

    puts "Removing #{user.email} from Mailchimp..."
    if MailchimpSyncService.remove_user(user)
      puts "✓ Successfully removed #{user.email}"
    else
      puts "✗ Failed to remove #{user.email}"
      exit 1
    end
  end

  desc "Show Mailchimp stats"
  task stats: :environment do
    users_with_subs = User.joins(:subscriptions).distinct.count
    active_count = Subscription.active.joins(:user).distinct.count(:user_id)
    paused_count = Subscription.paused.joins(:user).distinct.count(:user_id)
    completed_count = Subscription.completed.joins(:user).distinct.count(:user_id)
    pending_count = Subscription.pending.joins(:user).distinct.count(:user_id)

    puts "Mailchimp Sync Stats"
    puts "=" * 60
    puts "Total users with subscriptions: #{users_with_subs}"
    puts "  - Active subscriptions: #{active_count}"
    puts "  - Paused subscriptions: #{paused_count}"
    puts "  - Completed subscriptions: #{completed_count}"
    puts "  - Pending subscriptions: #{pending_count}"
    puts "=" * 60
  end
end
