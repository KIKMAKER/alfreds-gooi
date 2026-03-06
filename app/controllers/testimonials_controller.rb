class TestimonialsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_testimonial, only: [:destroy, :update]
  before_action :authorize_admin, only: [:index]
  before_action :authorize_own_or_admin, only: [:update]

  def new
    @testimonial = current_user.testimonials.build
  end

  def create
    @testimonial = current_user.testimonials.build(testimonial_params)

    if @testimonial.save
      redirect_to manage_path, notice: "Thank you for your testimonial!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    # Admin only - view all testimonials
    @testimonials = Testimonial.includes(:user).recent
  end

  def my_testimonials
    @testimonials = current_user.testimonials.recent
  end

  def update
    if @testimonial.update(testimonial_params)
      redirect_to current_user.admin? ? testimonials_path : my_testimonials_testimonials_path,
                  notice: "Testimonial updated"
    else
      redirect_to current_user.admin? ? testimonials_path : my_testimonials_testimonials_path,
                  alert: "Failed to update"
    end
  end

  def destroy
    if current_user.admin? || @testimonial.user == current_user
      @testimonial.destroy
      redirect_to current_user.admin? ? testimonials_path : manage_path,
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

  def authorize_own_or_admin
    unless current_user.admin? || @testimonial.user == current_user
      redirect_to manage_path, alert: "Access denied"
    end
  end

  def testimonial_params
    params.require(:testimonial).permit(:content, :public, :photo)
  end
end
