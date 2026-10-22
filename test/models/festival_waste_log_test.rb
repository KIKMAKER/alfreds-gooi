require "test_helper"

class FestivalWasteLogTest < ActiveSupport::TestCase
  setup do
    @event = FestivalEvent.create!(name: "Test fest", start_date: Date.today, end_date: Date.today + 2)
  end

  def organic(attrs = {})
    @event.festival_waste_logs.build({ day_number: 1, logged_at: Time.current,
                                       category: FestivalWasteLog::ORGANIC_CATEGORY }.merge(attrs))
  end

  test "subtracts the same tare as Bucket for each container size" do
    { 25 => Bucket::TARE_25L_KG, 45 => Bucket::TARE_45L_KG, 80 => Bucket::TARE_80L_KG }.each do |size, tare|
      log = organic(gross_kg: 20, container_size: size)
      assert log.valid?
      assert_in_delta 20 - tare, log.weight_kg.to_f, 0.0001
    end
  end

  test "no container means no tare" do
    log = organic(gross_kg: 12.4)
    assert log.valid?
    assert_in_delta 12.4, log.weight_kg.to_f, 0.0001
  end

  test "entries without gross keep the weight they were given" do
    log = organic(weight_kg: 7.5)
    assert log.valid?
    assert_in_delta 7.5, log.weight_kg.to_f, 0.0001
  end

  test "a reading at or under the tare is invalid, not negative" do
    log = organic(gross_kg: 1.0, container_size: 45)
    assert_not log.valid?
    assert_includes log.errors[:weight_kg], "must be greater than 0"
  end

  test "rejects unknown container sizes" do
    assert_not organic(gross_kg: 10, container_size: 60).valid?
  end
end
