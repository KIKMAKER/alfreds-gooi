require "test_helper"

class SuburbsControllerTest < ActionDispatch::IntegrationTest
  test "renders the launch page for a waitlist suburb" do
    suburb = Suburb.create!(name: "Launch Area", status: :waitlist, launch_date: Date.current + 3.weeks, collection_day: "Tuesday")

    get suburb_path(suburb)

    assert_response :success
    assert_select "h1", text: /kitchen scraps/i
  end

  test "404s for a suburb that is not on the waitlist" do
    suburb = suburb_fixture("Rondebosch", collection_day: "Tuesday")

    get suburb_path(suburb)

    assert_response :not_found
  end

  test "404s for a target suburb with no launch_date" do
    suburb = Suburb.create!(name: "Future Area", status: :target)

    get suburb_path(suburb)

    assert_response :not_found
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
