require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "payment-model-#{SecureRandom.hex(4)}@example.com",
      password: "password",
      phone_number: "+27800000002"
    )
  end

  # --- payment_type enum ---

  test "payment_type accepts eft" do
    p = Payment.create!(user: @user, payment_type: :eft, manual: true)
    assert p.eft?
    assert_equal "eft", p.payment_type
  end

  test "payment_type accepts snapscan" do
    p = Payment.create!(user: @user, payment_type: :snapscan, manual: true)
    assert p.snapscan?
  end

  test "payment_type accepts cash" do
    p = Payment.create!(user: @user, payment_type: :cash, manual: true)
    assert p.cash?
  end

  test "payment_type accepts other" do
    p = Payment.create!(user: @user, payment_type: :other, manual: true)
    assert p.other?
  end

  test "payment_type is nil by default" do
    p = Payment.create!(user: @user)
    assert_nil p.payment_type
  end

  # --- manual flag ---

  test "manual defaults to false" do
    p = Payment.create!(user: @user)
    assert_equal false, p.manual
  end

  test "manual can be set to true" do
    p = Payment.create!(user: @user, manual: true)
    assert p.manual
  end
end
