require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders successfully with the nav, hero, and impact strip" do
    get root_path

    assert_response :success
    assert_select ".new-nav-cta-btn", text: "Sign up"
    assert_select ".home-hero__title", text: /kitchen scraps/i
    assert_select ".impact-summary__grid .impact-summary__item", count: 3
    assert_select ".impact-summary__lifetime .impact-summary__item", count: 2
  end

  test "home computes live sitewide impact figures, not hardcoded" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    user = User.create!(first_name: "Neighbour", last_name: "Test", email: "neighbour_#{SecureRandom.hex(3)}@example.com", phone_number: "+2783#{rand(1_000_000..9_999_999)}", password: "password")
    Subscription.create!(user: user, plan: "Standard", duration: 6, suburb: suburb, street_address: "1 Test St", status: :active, collection_day: "Tuesday")

    get root_path

    assert_select ".impact-summary__number[data-counter-value=?]", Subscription.active.count.to_s
  end

  test "home derives lifetime compost and CO2e from the sitewide kg total" do
    DropOffSite.update_all(total_weight_kg: 0)
    site = DropOffSite.new(name: "Test Farm", slug: "test-farm-#{SecureRandom.hex(3)}", street_address: "1 Farm Rd",
                           collection_day: "Tuesday", suburb: suburb_fixture("Rondebosch", collection_day: "Tuesday"))
    site.save!(validate: false)
    site.update_columns(total_weight_kg: 1000)

    get root_path

    assert_select ".impact-summary__lifetime [data-counter-value=?]", (1000 * User::COMPOST_MULTIPLIER).round.to_s
    assert_select ".impact-summary__lifetime [data-counter-value=?]", (1000 * User::CO2E_MULTIPLIER).round.to_s
  end
end
