class Admin::WhatsappMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  def index
    @whatsapp_messages = WhatsappMessage.includes(:user, :subscription)
                                       .recent
                                       .limit(100)

    @stats = {
      total_sent: WhatsappMessage.count,
      delivered: WhatsappMessage.delivered.count,
      failed: WhatsappMessage.failed.count,
      today: WhatsappMessage.where('created_at >= ?', Date.today).count,
      template_used: WhatsappMessage.where(used_template: true).count
    }
  end

  def trigger_reminders
    # Manual trigger for testing
    date = params[:date]&.to_date || Date.tomorrow
    use_template = params[:use_template] == 'true' || params[:use_template].nil? # default true

    WhatsappReminderJob.perform_later(date, use_template: use_template)

    flash[:notice] = "WhatsApp reminders queued for #{date.strftime('%A, %B %d')} #{use_template ? '(using template)' : '(freeform)'}"
    redirect_to admin_whatsapp_messages_path
  end

  private

  def ensure_admin
    redirect_to root_path, alert: 'Access denied' unless current_user.admin?
  end
end
