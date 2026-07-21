class SuburbsController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @suburb = Suburb.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless @suburb.waitlist?

    @standard_og = Product.find_by(title: "Standard 6 month OG subscription")
    @xl_og = Product.find_by(title: "XL 6 month OG subscription")
  end
end
