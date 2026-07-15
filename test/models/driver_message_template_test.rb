# frozen_string_literal: true
require "test_helper"

class DriverMessageTemplateTest < ActiveSupport::TestCase
  test "body_for returns the coded default when nothing is saved" do
    assert_equal DriverMessageTemplate::DEFAULTS["once_off"], DriverMessageTemplate.body_for(:once_off)
  end

  test "body_for returns the saved body once set" do
    DriverMessageTemplate.create!(segment: "standard", body: "Custom standard message")
    assert_equal "Custom standard message", DriverMessageTemplate.body_for("standard")
  end

  test "body_for falls back to default when a saved body is blank" do
    DriverMessageTemplate.create!(segment: "commercial", body: "")
    assert_equal DriverMessageTemplate::DEFAULTS["commercial"], DriverMessageTemplate.body_for(:commercial)
  end

  test "bodies_by_segment covers every segment with defaults filled in" do
    DriverMessageTemplate.create!(segment: "new_customer", body: "Hi newbie")
    bodies = DriverMessageTemplate.bodies_by_segment

    assert_equal DriverMessageTemplate::SEGMENTS.sort, bodies.keys.sort
    assert_equal "Hi newbie", bodies["new_customer"]
    assert_equal DriverMessageTemplate::DEFAULTS["standard"], bodies["standard"]
  end

  test "segment must be one of the known segments and unique" do
    assert_not DriverMessageTemplate.new(segment: "nonsense").valid?

    DriverMessageTemplate.create!(segment: "standard", body: "a")
    dup = DriverMessageTemplate.new(segment: "standard", body: "b")
    assert_not dup.valid?
  end
end
