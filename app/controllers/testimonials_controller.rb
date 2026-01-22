class TestimonialsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_testimonial, only: [:destroy, :update]
  before_action :authorize_admin, only: [:index, :update]

  def new
    @testimonial = current_user.testimonials.build
  end

  def create
    @testimonial = current_user.testimonials.build(testimonial_params)

    if @testimonial.save
      redirect_to manage_path, notice: "Thank you for your testimonial! 🙏"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    # Admin only - view all testimonials
    @testimonials = Testimonial.includes(:user).recent
  end

  def update
    # Admin can toggle public/private
    if @testimonial.update(testimonial_params)
      redirect_to testimonials_path, notice: "Testimonial updated"
    else
      redirect_to testimonials_path, alert: "Failed to update testimonial"
    end
  end

  def destroy
    # Users can delete their own, admins can delete any
    if current_user.admin? || @testimonial.user == current_user
      @testimonial.destroy
      redirect_to (current_user.admin? ? testimonials_path : manage_path),
                  notice: "Testimonial deleted"
    else
      redirect_to manage_path, alert: "You can only delete your own testimonials"
    end
  end

  private

  def set_testimonial
    @testimonial = Testimonial.find(params[:id])
  end

  def authorize_admin
    redirect_to root_path, alert: "Access denied" unless current_user.admin?
  end

  def testimonial_params
    params.require(:testimonial).permit(:content, :public, :photo)
  end
end
