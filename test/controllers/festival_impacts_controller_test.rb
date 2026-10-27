require "test_helper"

class FestivalImpactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = FestivalEvent.create!(name: "Pangea 2026", start_date: Date.today, end_date: Date.today + 2,
                                   published: true, visible_facts: %w[to_pigs co2e car_km daily])
    @event.festival_waste_logs.create!(day_number: 1, logged_at: Time.current, category: "organic",
                                       gross_kg: 100, source: "vendor", destination: "pigs")
    @event.festival_waste_logs.create!(day_number: 2, logged_at: Time.current, category: "glass", weight_kg: 5)
  end

  test "slug is generated from the name" do
    assert_equal "pangea-2026", @event.slug
  end

  test "only the chosen facts are shown" do
    get festival_impact_path(@event.slug)
    assert_response :success
    assert_select ".festival-impact__card--to-pigs"
    assert_select ".festival-impact__card--co2e"
    assert_select ".festival-impact__card--daily"
    assert_select ".festival-impact__card--organics", count: 0
    assert_select ".festival-impact__card--trees", count: 0
  end

  test "unticking every fact still saves and shows an empty state" do
    @event.update!(visible_facts: [""])
    get festival_impact_path(@event.slug)
    assert_select ".festival-impact__empty"
  end

  test "unknown fact keys are dropped" do
    @event.update!(visible_facts: %w[co2e bogus])
    assert_equal %w[co2e], @event.visible_facts
  end

  test "co2e uses the shared factor" do
    kg = @event.festival_waste_logs.organic.sum(:weight_kg).to_f
    fact = @event.impact.facts(%w[co2e]).first
    assert_in_delta (kg * IMPACT[:co2e_per_kg_diverted]).round(1), fact.value, 0.1
  end

  test "drafts 404 for the public" do
    @event.update!(published: false)
    get festival_impact_path(@event.slug)
    assert_response :not_found
  end

  test "drafts are previewable by admins" do
    @event.update!(published: false)
    admin = User.create!(first_name: "Kiki", last_name: "Kennedy", phone_number: "+2783635#{rand(1000..9999)}",
                         password: "password", email: "admin-#{SecureRandom.hex(3)}@gmail.com", role: :admin)
    sign_in admin
    get festival_impact_path(@event.slug)
    assert_response :success
    assert_select ".festival-impact__draft"
  end
end
