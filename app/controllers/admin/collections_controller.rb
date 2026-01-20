class Admin::CollectionsController < ApplicationController
  # before_action :authenticate_user!  # keep if you use Devise
  # before_action :require_admin!      # if you gate admin

  def index
    @per  = params.fetch(:per, 200).to_i.clamp(1, 1000)
    @page = params.fetch(:page, 1).to_i

    scope = Collection
              .includes(subscription: :user) # avoid N+1
              .order(date: :desc, time: :desc, id: :desc)

    # Filters
    case params[:skip]
    when "true"  then scope = scope.where(skip: true)
    when "false" then scope = scope.where(skip: false)
    end
    scope = scope.where(updated_at: nil) if params[:missing_update] == "1"

    if params[:q].present?
      q = "%#{params[:q].strip.downcase}%"
      scope = scope.joins(subscription: :user)
                   .where("LOWER(users.first_name) LIKE :q
                           OR LOWER(users.last_name) LIKE :q
                           OR LOWER(users.email) LIKE :q
                           OR LOWER(subscriptions.suburb) LIKE :q
                           OR LOWER(subscriptions.street_address) LIKE :q", q: q)
    end

    @total       = scope.count
    @pages       = (@total.to_f / @per).ceil
    @collections = scope.offset((@page - 1) * @per).limit(@per)
  end

  def edit
    @collection = Collection.find(params[:id])
  end

  def update
    @collection = Collection.find(params[:id])
    if @collection.update(collection_params)
      redirect_to admin_collections_path, notice: "Collection updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Collection.find(params[:id]).destroy
    redirect_to admin_collections_path, notice: "Collection deleted."
  end

  def customer_map_data
    subscriptions = Subscription
      .active
      .includes(:user, collections: [])
      .where.not(latitude: nil, longitude: nil)

    features = subscriptions.map do |sub|
      # Get last 4 collections and calculate average total volume
      recent_collections = sub.collections.order(date: :desc).limit(4)

      if recent_collections.any?
        total_volumes = recent_collections.map do |c|
          # Sum all volume metrics: bags + buckets + buckets_45l + buckets_25l
          (c.bags || 0) + (c.buckets || 0) + (c.buckets_45l || 0) + (c.buckets_25l || 0)
        end
        avg_weekly_volume = (total_volumes.sum.to_f / recent_collections.count).round(2)

        # Separate bags and buckets for display
        avg_bags = (recent_collections.sum(&:bags) / recent_collections.count.to_f).round(2)
        avg_buckets = (recent_collections.map { |c| (c.buckets || 0) + (c.buckets_45l || 0) + (c.buckets_25l || 0) }.sum / recent_collections.count.to_f).round(2)
      else
        avg_weekly_volume = 0
        avg_bags = 0
        avg_buckets = 0
      end

      {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [sub.longitude, sub.latitude]
        },
        properties: {
          id: sub.id,
          plan: sub.plan,
          collection_day: sub.collection_day,
          avg_bags_weekly: avg_bags,
          avg_buckets_weekly: avg_buckets,
          avg_total_volume: avg_weekly_volume,
          marker_size: calculate_marker_size(sub, avg_bags, avg_buckets),
          customer_name: sub.user&.first_name || sub.user&.email,
          address: sub.short_address,
          suburb: sub.suburb,
          bucket_size: sub.Commercial? ? sub.bucket_size : nil,
          buckets_per_collection: sub.Commercial? ? sub.buckets_per_collection : nil
        }
      }
    end

    render json: { type: "FeatureCollection", features: features }
  end

  private

  def collection_params
    params.require(:collection).permit(:date, :time, :bags, :buckets, :buckets_45l, :buckets_25l, :skip, :alfred_message)
  end

  def calculate_marker_size(subscription, avg_bags, avg_buckets)
    if subscription.plan == "Standard"
      normalized = [avg_bags / 6.0, 1.0].min  # 0-6 bags typical
    elsif subscription.plan == "XL"
      normalized = [avg_buckets / 4.0, 1.0].min  # 0-4 buckets typical
    elsif subscription.Commercial?
      # Commercial: higher volumes (10-80 buckets per week possible)
      normalized = [avg_buckets / 20.0, 1.0].min  # 0-20 buckets typical range
    else
      normalized = 0
    end

    (6 + (normalized * 14)).round(1)  # 6px-20px range
  end
end
