class Admin::SuburbsController < Admin::BaseController
  before_action :set_suburb, only: [:edit, :update, :destroy, :start_launch, :go_live]

  def index
    @suburbs = Suburb.order(:name)
  end

  def new
    @suburb = Suburb.new
  end

  def create
    @suburb = Suburb.new(suburb_params)

    if @suburb.save
      redirect_to admin_suburbs_path, notice: "Suburb created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @suburb.update(suburb_params)
      redirect_to admin_suburbs_path, notice: "Suburb updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @suburb.destroy
      redirect_to admin_suburbs_path, notice: "Suburb deleted successfully!"
    else
      redirect_to admin_suburbs_path, alert: @suburb.errors.full_messages.to_sentence
    end
  end

  def start_launch
    if @suburb.start_launch!
      redirect_to admin_suburbs_path, notice: "#{@suburb.name} is now on the pre-launch waitlist."
    else
      redirect_to admin_suburbs_path, alert: "Set a launch date before starting pre-launch."
    end
  end

  def go_live
    if @suburb.go_live!
      redirect_to admin_suburbs_path, notice: "#{@suburb.name} is live!"
    else
      redirect_to admin_suburbs_path, alert: "#{@suburb.name} isn't on the pre-launch waitlist."
    end
  end

  private

  def set_suburb
    @suburb = Suburb.find(params[:id])
  end

  def suburb_params
    params.require(:suburb).permit(:name, :status, :collection_day, :launch_date)
  end
end
