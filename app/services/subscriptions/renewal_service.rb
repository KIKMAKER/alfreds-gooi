# app/services/subscriptions/renewal_service.rb
# Purpose: duplicate a user's last subscription and generate an invoice for the new one.
# Usage: Subscriptions::RenewalService.call(user: user)
#
# Options:
#   - plan_to_product (Hash or Proc): maps a plan (string/symbol) to a Product
#     Example hash: { "Standard" => -> { Product.find_by(title: "Standard subscription") } }
#
# Returns a Result object with:
#   success? (bool), subscription, invoice, error (string)

module Subscriptions
  class RenewalService
    Result = Struct.new(:success?, :subscription, :invoice, :error, keyword_init: true)

    def initialize(user:, plan_to_product: nil)
      @user            = user
      @plan_to_product = plan_to_product
    end

    def call
      last_sub = @user.subscriptions.order(Arel.sql("COALESCE(end_date, '1900-01-01') DESC"), created_at: :desc).first
      return failure!("No previous subscription to duplicate.") unless last_sub

      new_sub = build_subscription_from(last_sub)

      ActiveRecord::Base.transaction do
        new_sub.save!

        # ⬇️ Use InvoiceBuilder instead of ad-hoc invoice creation
        invoice = InvoiceBuilder.new(
          subscription: new_sub,
          og:           @user.respond_to?(:og) ? @user.og : false,
          is_new:       false
          # referee:, referred_friends: — include if you want to drive referral discounts here
        ).call

        return success!(subscription: new_sub, invoice: invoice)
      end
    end

    private

    def success!(subscription:, invoice:)
      Result.new(success?: true, subscription: subscription, invoice: invoice)
    end

    def failure!(message)
      Result.new(success?: false, error: message)
    end

    def build_subscription_from(last_sub)
      start_date      = (last_sub.end_date.presence || Time.zone.today).to_date + 1.day
      duration_months = (last_sub.duration.presence || 1).to_i

      duped = last_sub.dup
      duped.assign_attributes(
        start_date: start_date,
        duration:   duration_months,
        end_date:   start_date.advance(months: duration_months),
        status:     (duped.respond_to?(:status) ? "pending" : nil),
        is_paused:  (duped.respond_to?(:is_paused) ? false : nil)
      )
      duped.user = @user
      duped.customer_id ||= @user.customer_id
      duped
    end
  end
end
