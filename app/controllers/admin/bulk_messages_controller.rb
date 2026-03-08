class Admin::BulkMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def index
    @message = params[:message]
    @contacts = filter_contacts
  end

  private

  def filter_contacts
    subscriptions = case params[:status_filter]
                    when 'all_active'
                      Subscription.active
                    when 'new_customers'
                      Subscription.active.where('start_date >= ?', 30.days.ago)
                    when 'long_term'
                      Subscription.active.where('start_date <= ?', 12.months.ago)
                    when 'paused'
                      Subscription.where(status: :pause)
                    when 'recently_completed'
                      Subscription.where(status: :completed).where('updated_at >= ?', 2.weeks.ago)
                    when 'all_completed'
                      Subscription.where(status: :completed)
                    when 'all_pending'
                      Subscription.pending
                    when 'legacy'
                      Subscription.where(status: :legacy)
                    else
                      Subscription.active
                    end

    if params[:collection_day].present? && params[:collection_day] != 'all'
      subscriptions = subscriptions.where(collection_day: params[:collection_day])
    end

    if params[:suburb].present? && params[:suburb] != 'all'
      subscriptions = subscriptions.where(suburb: params[:suburb])
    end

    if params[:plan].present? && params[:plan] != 'all'
      subscriptions = subscriptions.where(plan: params[:plan])
    end

    if params[:min_collections].present?
      subscription_ids = subscriptions.select { |sub| sub.total_collections >= params[:min_collections].to_i }.map(&:id)
      subscriptions = Subscription.where(id: subscription_ids)
    end

    if params[:max_collections].present?
      subscription_ids = subscriptions.select { |sub| sub.total_collections <= params[:max_collections].to_i }.map(&:id)
      subscriptions = Subscription.where(id: subscription_ids)
    end

    if params[:date_from].present?
      subscriptions = subscriptions.where('start_date >= ?', params[:date_from])
    end

    if params[:date_to].present?
      subscriptions = subscriptions.where('start_date <= ?', params[:date_to])
    end

    contacts = Contact.where(subscription_id: subscriptions.select(:id))
                      .includes(subscription: :user)

    # Contact-level filters
    contacts = contacts.can_receive_whatsapp if params[:opted_in_only] == '1'
    contacts = contacts.primary if params[:primary_only] == '1'

    if params[:relationship].present? && params[:relationship] != 'all'
      if params[:relationship] == 'owner'
        contacts = contacts.primary
      else
        contacts = contacts.where(relationship: params[:relationship])
      end
    end

    contacts.order('contacts.first_name, contacts.last_name')
  end

  def ensure_admin
    redirect_to root_path, alert: 'Not authorized' unless current_user&.admin?
  end
end
