class Admin::PostsController < Admin::BaseController
  before_action :set_post, only: [:show, :edit, :update, :destroy]

  def index
    @posts = Post.order(created_at: :desc)
  end

  def new
    @post = Post.new
  end

  def create
    @post = Post.new(post_params)
    @post.published_at = Time.current if @post.published? && @post.published_at.blank?

    if @post.save
      redirect_to admin_posts_path, notice: "Post created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @post.published_at ||= Time.current if post_params[:published] == "1" && @post.published_at.blank?

    if @post.update(post_params)
      redirect_to admin_posts_path, notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    redirect_to admin_posts_path, notice: "Post deleted."
  end

  private

  def set_post
    @post = Post.find(params[:id])
  end

  def post_params
    params.require(:post).permit(:title, :slug, :body, :excerpt, :cover_image_url, :published, :published_at)
  end
end
