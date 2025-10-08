require "test_helper"

class DropOffEventMailerTest < ActionMailer::TestCase
  test "completion_notification" do
    mail = DropOffEventMailer.completion_notification
    assert_equal "Completion notification", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
