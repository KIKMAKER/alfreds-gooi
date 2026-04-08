class Admin::InterestsController < Admin::BaseController
  before_action :set_interest, only: %i[show edit update destroy]

  def index
    @interests = Interest.order(created_at: :desc)
    @by_suburb = @interests.group_by(&:suburb)
                           .sort_by { |_, entries| -entries.size }
  end

  def show; end

  def edit; end

  def update
    if @interest.update(interest_params)
      redirect_to admin_interest_path(@interest), notice: "Interest updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @interest.destroy
    redirect_to admin_interests_path, notice: "Interest deleted."
  end

  private

  def set_interest
    @interest = Interest.find(params[:id])
  end

  def interest_params
    params.require(:interest).permit(:name, :email, :suburb, :note)
  end
end
