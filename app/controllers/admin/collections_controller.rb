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

  private

  def collection_params
    params.require(:collection).permit(:date, :time, :bags, :skip, :alfred_message)
  end
end
