class PostsController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    @posts = Post.published
  end

  def show
    @post = Post.published.find_by!(slug: params[:slug])
  end
end
