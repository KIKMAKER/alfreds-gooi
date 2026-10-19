class FacilityLetterMailer < ApplicationMailer
  # To Gooi: a manager has uploaded a signed letter. The file is attached so it
  # can be read straight from the inbox; approval happens on the admin site page.
  def submitted(site)
    @site = site
    letter = site.facility_confirmation_letter
    attachments[letter.filename.to_s] = letter.download

    mail(
      to: ENV["FACILITY_LETTER_NOTIFY_TO"] || "howzit@gooi.me",
      subject: "Facility letter to review: #{site.name}"
    )
  end

  # To the manager. The wording only mentions payment for sites that charge.
  def approved(site)
    @site = site
    @user = site.user
    mail(to: @user.email, reply_to: "howzit@gooi.me", subject: "#{site.name} is now a listed Gooi facility")
  end

  def rejected(site)
    @site = site
    @user = site.user
    mail(to: @user.email, reply_to: "howzit@gooi.me", subject: "We couldn't accept your facility letter for #{site.name}")
  end
end
