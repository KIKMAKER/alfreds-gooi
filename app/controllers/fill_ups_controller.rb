class FillUpsController < ApplicationController
  def new
    @fill_up = FillUp.new
    @user = current_user
  end

  def create
    @fill_up = FillUp.new(fill_up_params)
    @fill_up.user = current_user
    @fill_up.date = DateTime.now
    @fill_up.car = Car.first
    if @fill_up.save
      # redirect_to root_path
      redirect_to fill_ups_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @fill_ups = FillUp.all
  end

  private

  def fill_up_params
    params.require(:fill_up).permit(:volume, :odometer, :cost, :notes)
  end
end
