class BlocksController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @block = Block.find_by!(slug: params[:slug])
  end
end
