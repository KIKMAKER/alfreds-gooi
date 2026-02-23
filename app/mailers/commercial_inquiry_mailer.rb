class CommercialInquiryMailer < ApplicationMailer
  def notify_admin(inquiry)
    @inquiry = inquiry
    @user = inquiry.user

    mail(
      to: 'howzit@gooi.me',
      subject: "New Commercial Inquiry from #{@user.first_name} #{@user.last_name}"
    )
  end

  def notify_customer(inquiry)
    @inquiry = inquiry
    @user = inquiry.user

    mail(
      to: @user.email,
      subject: "Thanks for your interest in Gooi Commercial Collection"
    )
  end
end
