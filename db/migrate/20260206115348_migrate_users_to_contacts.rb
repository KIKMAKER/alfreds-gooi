class MigrateUsersToContacts < ActiveRecord::Migration[7.2]
  def up
    Subscription.find_each do |subscription|
      user = subscription.user
      next unless user # Skip if no user (shouldn't happen)

      # Create primary contact from user
      Contact.create!(
        subscription: subscription,
        first_name: user.first_name || 'Primary',
        last_name: user.last_name,
        phone_number: user.phone_number || '',
        relationship: 'owner',
        is_primary: true,
        whatsapp_opt_out: user.whatsapp_opt_out || false
      )
    rescue ActiveRecord::RecordInvalid => e
      # Log but continue - some subscriptions might have issues
      Rails.logger.error "Failed to create contact for subscription #{subscription.id}: #{e.message}"
    end
  end

  def down
    Contact.where(is_primary: true).destroy_all
  end
end
