class Admin::BlocksController < Admin::BaseController
  before_action :set_block, only: [:show, :edit, :update, :destroy, :assign_subscription, :remove_subscription]

  def index
    @blocks = Block.order(:name)
  end

  def show
    @subscriptions = @block.subscriptions.includes(:user).order("users.first_name")
    # Unassigned active subscriptions for the assignment form
    @unassigned_subscriptions = Subscription.where(block_id: nil)
                                             .where(status: :active)
                                             .joins(:user)
                                             .order("users.first_name")
  end

  def new
    @block = Block.new
  end

  def create
    @block = Block.new(block_params)
    if @block.save
      redirect_to admin_block_path(@block), notice: "Block created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @block.update(block_params)
      redirect_to admin_block_path(@block), notice: "Block updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @block.destroy
    redirect_to admin_blocks_path, notice: "Block removed."
  end

  # POST /admin/blocks/:id/assign_subscription
  def assign_subscription
    sub = Subscription.find(params[:subscription_id])
    sub.update!(block: @block)
    redirect_to admin_block_path(@block), notice: "#{sub.user.first_name} #{sub.user.last_name} assigned to #{@block.name}."
  end

  # DELETE /admin/blocks/:id/remove_subscription?subscription_id=X
  def remove_subscription
    sub = @block.subscriptions.find(params[:subscription_id])
    sub.update!(block: nil)
    redirect_to admin_block_path(@block), notice: "Subscription removed from block."
  end

  private

  def set_block
    @block = Block.find(params[:id])
  end

  def block_params
    params.require(:block).permit(
      :name, :slug, :description,
      :resident_count,
      photos: []
    )
  end
end
