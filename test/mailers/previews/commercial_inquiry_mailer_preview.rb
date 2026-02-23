# Preview all emails at http://localhost:3000/rails/mailers/commercial_inquiry_mailer
class CommercialInquiryMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/commercial_inquiry_mailer/notify_admin
  def notify_admin
    CommercialInquiryMailer.notify_admin
  end

  # Preview this email at http://localhost:3000/rails/mailers/commercial_inquiry_mailer/notify_customer
  def notify_customer
    CommercialInquiryMailer.notify_customer
  end
end
