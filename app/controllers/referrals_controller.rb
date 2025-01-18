class ReferralsController < ApplicationController
  def show
    @referrals = current_user.referrals_as_referrer
  end
end
