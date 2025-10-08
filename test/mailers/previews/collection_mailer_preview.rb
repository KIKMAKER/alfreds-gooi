# Preview all emails at http://localhost:3000/rails/mailers/collection_mailer
class CollectionMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/collection_mailer/skipped
  def skipped
    CollectionMailer.skipped
  end
end
