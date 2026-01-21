# frozen_string_literal: true

class MailchimpSyncService
  LIST_ID = ENV['MAILCHIMP_LIST_ID']

  class << self
    # Sync a single user to Mailchimp
    def sync_user(user)
      return unless LIST_ID.present?
      return unless user.email.present?

      new.sync_user(user)
    end

    # Sync all users with subscriptions
    def sync_all_users
      return unless LIST_ID.present?

      users = User.joins(:subscriptions).distinct
      results = { synced: 0, failed: 0, errors: [] }

      users.find_each do |user|
        if sync_user(user)
          results[:synced] += 1
        else
          results[:failed] += 1
        end
      rescue StandardError => e
        results[:failed] += 1
        results[:errors] << { user_id: user.id, email: user.email, error: e.message }
      end

      results
    end

    # Remove a user from Mailchimp (when they request deletion)
    def remove_user(user)
      return unless LIST_ID.present?
      return unless user.email.present?

      new.remove_user(user)
    end
  end

  def initialize
    @gibbon = Gibbon::Request.new
  end

  def sync_user(user)
    subscription = user.subscriptions.order(created_at: :desc).first
    return false unless subscription

    member_data = build_member_data(user, subscription)
    subscriber_hash = Digest::MD5.hexdigest(user.email.downcase)

    # Upsert member (creates or updates)
    @gibbon.lists(LIST_ID)
            .members(subscriber_hash)
            .upsert(body: member_data)

    Rails.logger.info "Synced #{user.email} to Mailchimp with status: #{subscription.status}"
    true
  rescue Gibbon::MailChimpError => e
    Rails.logger.error "Mailchimp sync failed for #{user.email}: #{e.message}"
    false
  end

  def remove_user(user)
    subscriber_hash = Digest::MD5.hexdigest(user.email.downcase)

    # Permanently delete from Mailchimp
    @gibbon.lists(LIST_ID)
            .members(subscriber_hash)
            .delete

    Rails.logger.info "Removed #{user.email} from Mailchimp"
    true
  rescue Gibbon::MailChimpError => e
    Rails.logger.error "Mailchimp removal failed for #{user.email}: #{e.message}"
    false
  end

  private

  def build_member_data(user, subscription)
    {
      email_address: user.email,
      status: mailchimp_status(subscription),
      merge_fields: {
        FNAME: user.first_name || '',
        LNAME: user.last_name || '',
        PHONE: user.phone_number || '',
        PLAN: subscription.plan || '',
        SUBURB: subscription.suburb || '',
        COLLDAY: subscription.collection_day || '',
        CUSTID: subscription.customer_id || '',
        CREATED: user.created_at.strftime("%b %d, %Y"),
        SUB_START: subscription.created_at.strftime("%B %Y")
      },
      tags: mailchimp_tags(user, subscription)
    }
  end

  def mailchimp_status(subscription)
    # Mailchimp statuses: subscribed, unsubscribed, cleaned, pending
    # We'll mark everyone as 'subscribed' so they're in the list
    # Then use tags to segment by actual subscription status
    'subscribed'
  end

  def mailchimp_tags(user, subscription)
    tags = []

    # Subscription status tags
    case subscription.status
    when 'active'
      tags << 'Active Customer'
    when 'pause'
      tags << 'Paused'
    when 'pending'
      tags << 'Pending'
    when 'completed'
      tags << 'Completed'
    when 'legacy'
      tags << 'Legacy'
    end

    # Plan type tags
    case subscription.plan
    when 'Standard'
      tags << 'Standard Plan'
    when 'XL'
      tags << 'XL Plan'
    when 'Commercial'
      tags << 'Commercial Plan'
    end

    # Collection day tags
    if subscription.collection_day.present?
      tags << "#{subscription.collection_day} Collection"
    end

    # Driver/Admin tags
    tags << 'Driver' if user.driver?
    tags << 'Admin' if user.admin?

    tags
  end
end
