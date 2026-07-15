class Admin::DriverMessageTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  # Save all four segment templates at once from the form on the bulk messages
  # page. A blank body is allowed — it falls back to the coded default.
  def update
    submitted = params.fetch(:driver_message_templates, {})

    DriverMessageTemplate::SEGMENTS.each do |segment|
      next unless submitted.key?(segment)

      DriverMessageTemplate.find_or_initialize_by(segment: segment)
                           .update!(body: submitted[segment].to_s)
    end

    redirect_to admin_bulk_messages_path(anchor: "driver-templates"),
                notice: "Driver route messages saved."
  end

  private

  def ensure_admin
    redirect_to root_path, alert: "Not authorized" unless current_user&.admin?
  end
end
