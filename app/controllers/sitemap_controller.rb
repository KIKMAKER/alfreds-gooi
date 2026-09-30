class SitemapController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @posts = Post.published

    respond_to do |format|
      format.xml
    end
  end
end
