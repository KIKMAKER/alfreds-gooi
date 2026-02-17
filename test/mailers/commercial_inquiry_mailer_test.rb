require "test_helper"

class CommercialInquiryMailerTest < ActionMailer::TestCase
  test "notify_admin" do
    mail = CommercialInquiryMailer.notify_admin
    assert_equal "Notify admin", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "notify_customer" do
    mail = CommercialInquiryMailer.notify_customer
    assert_equal "Notify customer", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
