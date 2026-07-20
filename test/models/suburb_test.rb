require "test_helper"

class SuburbTest < ActiveSupport::TestCase
  test "generates a slug from the name" do
    suburb = Suburb.create!(name: "Sea Point")
    assert_equal "sea-point", suburb.slug
  end

  test "generates a collision-safe slug" do
    Suburb.create!(name: "Sea Point")
    suburb = Suburb.create!(name: "Sea Point!!")
    assert_equal "sea-point-1", suburb.slug
  end

  test "defaults to active status" do
    suburb = Suburb.create!(name: "Woodstock")
    assert suburb.active?
  end

  test "enforces unique name" do
    Suburb.create!(name: "Rondebosch")
    duplicate = Suburb.new(name: "Rondebosch")
    assert_not duplicate.valid?
  end
end
