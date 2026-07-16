class Admin::DriverMessageTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def edit
    @driver_templates = DriverMessageTemplate.bodies_by_segment
  end

  # Save all four segment templates at once. A blank body is allowed — it falls
  # back to the coded default.
  def update
    submitted = params.fetch(:driver_message_templates, {})

    DriverMessageTemplate::SEGMENTS.each do |segment|
      next unless submitted.key?(segment)

      DriverMessageTemplate.find_or_initialize_by(segment: segment)
                           .update!(body: submitted[segment].to_s)
    end

    redirect_to edit_admin_driver_message_templates_path,
                notice: "Driver route messages saved."
  end

  private

  def ensure_admin
    redirect_to root_path, alert: "Not authorized" unless current_user&.admin?
  end
end
