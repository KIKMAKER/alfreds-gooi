require "test_helper"

class CollectionMailerTest < ActionMailer::TestCase
  test "skipped" do
    mail = CollectionMailer.skipped
    assert_equal "Skipped", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
