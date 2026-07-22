require "test_helper"

class SuburbsControllerTest < ActionDispatch::IntegrationTest
  test "renders the launch page for a waitlist suburb" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")

    get suburb_path(suburb)

    assert_response :success
    assert_select "h1", text: /kitchen scraps/i
  end

  test "renders the interest page for a target suburb, with no pricing or sign-up CTA" do
    suburb = Suburb.create!(name: "Future Area", status: :target)

    get suburb_path(suburb)

    assert_response :success
    assert_select "h1", text: /kitchen scraps/i
    assert_select ".suburb-hero__overlay-card-main", text: /Not in Future Area yet/
    assert_select "#pricing", count: 0
    assert_select "a[href*='new_account_signup']", count: 0
  end

  test "target-suburb page links to the homepage interest form with the suburb preselected" do
    suburb = Suburb.create!(name: "Future Area", status: :target)

    get suburb_path(suburb)

    assert_select ".suburb-hero__cta[href=?]", "/?suburb_id=#{suburb.id}#interest"
    assert_select ".other-option-card--interest a[href=?]", "/?suburb_id=#{suburb.id}#interest"
    assert_select ".other-option-card--commercial", count: 0
  end

  test "404s for a drop_off_only suburb" do
    suburb = Suburb.create!(name: "Drop Off Area", status: :drop_off_only)

    get suburb_path(suburb)

    assert_response :not_found
  end

  test "renders the active-suburb page with collection day and a sign-up link to home page pricing" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")

    get suburb_path(suburb)

    assert_response :success
    assert_select "h1", text: /kitchen scraps/i
    assert_select ".suburb-hero__overlay-card-sub", text: /Tuesday/
    assert_select ".suburb-hero__cta[href=?]", "/#pricing"
    assert_select "#pricing", count: 0
  end

  test "active-suburb page shows impact stats in the hero with the right household count" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")
    2.times do |i|
      user = User.create!(first_name: "Neighbour#{i}", last_name: "Test", email: "neighbour#{i}_#{SecureRandom.hex(3)}@example.com", phone_number: "+2783#{rand(1_000_000..9_999_999)}", password: "password")
      Subscription.create!(user: user, plan: "Standard", duration: 6, suburb: suburb, street_address: "1 Test St", status: :active, collection_day: "Tuesday")
    end

    get suburb_path(suburb)

    assert_response :success
    assert_select ".suburb-hero__stats", text: /2 neighbours gooi-ing weekly/
  end

  test "pricing card links carry suburb_id, plan, duration, and og=true" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")
    Product.find_or_create_by!(title: "Standard 6 month OG subscription") { |p| p.description = "OG rate"; p.price = 720; p.billing_type = "invoice_only" }
    Product.find_or_create_by!(title: "XL 6 month OG subscription") { |p| p.description = "OG rate"; p.price = 960; p.billing_type = "invoice_only" }

    get suburb_path(suburb)

    assert_select "a[href*='plan=Standard'][href*='duration=6'][href*=\"suburb_id=#{suburb.id}\"][href*='og=true']"
    assert_select "a[href*='plan=XL'][href*='duration=6'][href*=\"suburb_id=#{suburb.id}\"][href*='og=true']"
  end
end
