class Admin::BlocksController < Admin::BaseController
  before_action :set_block, only: [:show, :edit, :update, :destroy, :assign_subscription, :remove_subscription, :send_pitch]

  def index
    @blocks = Block.includes(:subscriptions, :block_survey_responses, :quotations).order(:name)
  end

  def show
    @subscriptions = @block.subscriptions
                           .eager_load(:user)
                           .order("users.first_name")
                           .to_a

    @unassigned_subscriptions = Subscription
      .eager_load(:user)
      .where(block_id: nil)
      .where(status: %i[pending active pause])
      .order("users.first_name")
      .to_a

    @stat_week_l     = @block.actual_volume_this_week_l
    @stat_month_l    = @block.actual_volume_this_month_l
    @stat_lifetime_l = @block.lifetime_volume_l
    @stat_expected_l = @block.expected_weekly_volume_l

    @survey_responses = @block.block_survey_responses.order(created_at: :desc)
    @quotations       = @block.quotations.order(created_at: :desc)
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
    attrs = block_params
    # has_many_attached replaces the whole collection when the key is present,
    # even if no files were chosen. Strip it out so existing photos are kept
    # whenever the file input is left blank.
    attrs = attrs.except(:photos) if attrs[:photos].blank? || attrs[:photos].all?(&:blank?)
    if @block.update(attrs)
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

  # POST /admin/blocks/:id/send_pitch
  def send_pitch
    email          = params[:recipient_email].to_s.strip
    recipient_name = params[:recipient_name].to_s.strip
    quotation      = @block.quotations.find_by(id: params[:quotation_id])

    if email.blank?
      redirect_to admin_block_path(@block), alert: "Please enter a recipient email." and return
    end
    if quotation.nil?
      redirect_to admin_block_path(@block), alert: "Please select a quotation to include." and return
    end

    BlockSurveyMailer.pitch(@block, quotation, recipient_name.presence || "there", email).deliver_now
    redirect_to admin_block_path(@block), notice: "Pitch email sent to #{email}."
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
