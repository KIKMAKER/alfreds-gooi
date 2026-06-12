class BlockSurveysController < ApplicationController
  skip_before_action :authenticate_user!

  before_action :set_block

  def show
  end

  def create
    @response = @block.block_survey_responses.build(survey_params)
    if @response.save
      redirect_to block_survey_thanks_path(@block.slug)
    else
      render :show, status: :unprocessable_entity
    end
  end

  def thanks
  end

  private

  def set_block
    @block = Block.find_by!(slug: params[:block_slug])
  end

  def survey_params
    params.require(:block_survey_response).permit(
      :has_compost_bin,
      :wants_to_buy_bin,
      :wants_phase_one,
      :respondent_name,
      :unit_number
    )
  end
end
