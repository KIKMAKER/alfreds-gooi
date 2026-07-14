class Admin::BulkMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def index
    @message = params[:message]
    @contacts = filter_contacts
    @action_collections = action_collections_by_subscription
  end

  private

  # Per-collection action links resolve against the collection on the filtered
  # date. Each placeholder names the token it needs minted.
  ACTION_LINK_MINTERS = {
    "{soil_bag_link}" => :ensure_soil_bag_token!,
    "{skip_link}"     => :ensure_skip_token!
  }.freeze

  # Collections on the filtered date, keyed by subscription, with any tokens the
  # message references minted. These links target one specific collection, so
  # they only resolve when the admin has filtered to a collection date; contacts
  # with no collection on that date render an empty string rather than a broken
  # link.
  #
  # Minting writes a token, so it only happens for placeholders actually present
  # in the message — browsing the page leaves the collections untouched.
  def action_collections_by_subscription
    return {} if params[:collection_date].blank?

    minters = ACTION_LINK_MINTERS.select { |placeholder, _| @message.to_s.include?(placeholder) }.values
    return {} if minters.empty?

    collections = Collection.where(date: params[:collection_date],
                                   subscription_id: @contacts.map(&:subscription_id).uniq)
    collections.each { |collection| minters.each { |minter| collection.public_send(minter) } }
    collections.index_by(&:subscription_id)
  end

  def filter_contacts
    subscriptions = case params[:status_filter]
                    when 'all_active'
                      Subscription.active
                    when 'new_customers'
                      Subscription.active.where(is_new_customer: true)
                    when 'long_term'
                      Subscription.active.where('start_date <= ?', 12.months.ago)
                    when 'paused'
                      Subscription.where(status: :pause)
                    when 'recently_completed'
                      from = params[:completed_from].present? ? params[:completed_from] : 2.weeks.ago.to_date
                      to   = params[:completed_to].present?   ? params[:completed_to]   : Date.today
                      Subscription.where(status: :completed).where(end_date: from..to)
                    when 'all_completed'
                      base = Subscription.where(status: :completed)
                      base = base.where('end_date >= ?', params[:completed_from]) if params[:completed_from].present?
                      base = base.where('end_date <= ?', params[:completed_to])   if params[:completed_to].present?
                      base
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

    if params[:collection_date].present?
      subscriptions = subscriptions.joins(:collections)
                                   .where(collections: { date: params[:collection_date] })
      case params[:collection_subset]
      when 'normal'
        subscriptions = subscriptions.where(collections: { skip: false, new_customer: false })
      when 'skipped'
        subscriptions = subscriptions.where(collections: { skip: true })
      when 'new_customer'
        subscriptions = subscriptions.where(collections: { skip: false, new_customer: true })
      end
      subscriptions = subscriptions.distinct
    end

    if params[:suburb].present? && params[:suburb] != 'all'
      subscriptions = subscriptions.where(suburb: params[:suburb])
    end

    if params[:plan].present? && params[:plan] != 'all'
      subscriptions = subscriptions.where(plan: params[:plan])
    end

    if params[:min_collections].present?
      min = params[:min_collections].to_i
      qualifying_ids = Collection.where(skip: false, subscription_id: subscriptions.select(:id))
                                 .group(:subscription_id)
                                 .having("COUNT(*) >= ?", min)
                                 .select(:subscription_id)
      subscriptions = subscriptions.where(id: qualifying_ids)
    end

    if params[:max_collections].present?
      max = params[:max_collections].to_i
      qualifying_ids = Collection.where(skip: false, subscription_id: subscriptions.select(:id))
                                 .group(:subscription_id)
                                 .having("COUNT(*) <= ?", max)
                                 .select(:subscription_id)
      subscriptions = subscriptions.where(id: qualifying_ids)
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
    contacts = contacts.where(is_primary: false) if params[:non_primary_only] == '1'

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
