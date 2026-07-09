require "test_helper"

class DriversDayTest < ActiveSupport::TestCase
  def build_day(start_time:, end_time:, **attrs)
    DriversDay.new(user: User.new, total_buckets: 0, start_time: start_time, end_time: end_time, **attrs)
  end

  test "accepts a normal same-day route" do
    day = build_day(
      start_time: Time.zone.parse("2026-07-08 08:30"),
      end_time:   Time.zone.parse("2026-07-08 16:00")
    )
    day.valid?
    assert_empty day.errors[:end_time]
    assert_nil day.end_time_flag
  end

  test "rejects an end_time before the start_time" do
    day = build_day(
      start_time: Time.zone.parse("2026-07-08 18:03"),
      end_time:   Time.zone.parse("2026-07-08 16:22")
    )
    assert day.invalid?
    assert_equal :inverted, day.end_time_flag
    assert_match(/before the start time/, day.errors[:end_time].first)
  end

  test "rejects an end_time more than 12 hours after start" do
    day = build_day(
      start_time: Time.zone.parse("2026-07-08 08:00"),
      end_time:   Time.zone.parse("2026-07-08 21:00") # 13h
    )
    assert day.invalid?
    assert_equal :too_long, day.end_time_flag
  end

  test "rejects a short route that still crosses midnight" do
    day = build_day(
      start_time: Time.zone.parse("2026-07-08 22:00"),
      end_time:   Time.zone.parse("2026-07-09 02:00") # 4h but different calendar day
    )
    assert day.invalid?
    assert_equal :different_day, day.end_time_flag
  end

  test "override lets a genuinely long day through" do
    day = build_day(
      start_time: Time.zone.parse("2026-07-08 08:00"),
      end_time:   Time.zone.parse("2026-07-08 21:00"), # 13h
      override_end_time_warning: true
    )
    day.valid?
    assert_empty day.errors[:end_time]
  end

  test "does not flag when end_time is not yet set" do
    day = build_day(start_time: Time.zone.parse("2026-07-08 08:00"), end_time: nil)
    day.valid?
    assert_empty day.errors[:end_time]
    assert_nil day.end_time_flag
  end
end
