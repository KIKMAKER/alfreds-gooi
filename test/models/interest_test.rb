require "test_helper"

class InterestTest < ActiveSupport::TestCase
  test "can reference a target suburb" do
    suburb = Suburb.create!(name: "Bellville", status: :target)
    interest = Interest.create!(name: "Test", email: "test@example.com", suburb: suburb)

    assert_equal suburb, interest.suburb
  end

  test "suburb is optional, representing the Other option" do
    interest = Interest.new(name: "Test", email: "test@example.com", suburb: nil)

    assert interest.valid?
  end
end
