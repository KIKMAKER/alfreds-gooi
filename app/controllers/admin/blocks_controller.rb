class Admin::BlocksController < Admin::BaseController
  before_action :set_block, only: [:show, :edit, :update, :destroy, :assign_subscription, :remove_subscription]

  def index
    @blocks = Block.order(:name)
  end

  def show
    # eager_load forces a single LEFT OUTER JOIN query; .to_a materialises so
    # .count / .any? in the view use in-memory arrays, not extra DB hits.
    @subscriptions = @block.subscriptions
                           .eager_load(:user)
                           .order("users.first_name")
                           .to_a

    # Widen to pending + active + paused — completed/legacy subs shouldn't be assignable.
    # eager_load(:user) avoids the N+1 when rendering user names in the <select>.
    @unassigned_subscriptions = Subscription
      .eager_load(:user)
      .where(block_id: nil)
      .where(status: %i[pending active pause])
      .order("users.first_name")
      .to_a

    # Pre-compute stats once so the view never calls the same method twice.
    @stat_week_l     = @block.actual_volume_this_week_l
    @stat_month_l    = @block.actual_volume_this_month_l
    @stat_lifetime_l = @block.lifetime_volume_l
    @stat_expected_l = @block.expected_weekly_volume_l
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
