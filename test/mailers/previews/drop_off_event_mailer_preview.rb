# Preview all emails at http://localhost:3000/rails/mailers/drop_off_event_mailer
class DropOffEventMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/drop_off_event_mailer/completion_notification
  def completion_notification
    DropOffEventMailer.completion_notification
  end
end
