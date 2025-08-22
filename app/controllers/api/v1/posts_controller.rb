class Api::V1::PostsController < ApplicationController
  before_action :set_post, only: [:show, :update, :destroy, :publish, :unpublish]
  
  def index
    @posts = Post.includes(:user, :categories).all
    render json: @posts, include: [:user, :categories]
  end

  def show
    render json: @post, include: [:user, :categories]
  end

  def create
    @post = Post.new(post_params)
    
    if @post.save
      render json: @post, status: :created
    else
      render json: { errors: @post.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @post.update(post_params)
      render json: @post
    else
      render json: { errors: @post.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy
    head :no_content
  end
  
  def publish
    @post.update(status: 'published', published_at: Time.current)
    render json: @post
  end
  
  def unpublish
    @post.update(status: 'draft', published_at: nil)
    render json: @post
  end
  
  private
  
  def set_post
    @post = Post.find(params[:id])
  end
  
  def post_params
    params.require(:post).permit(:user_id, :title, :slug, :content, :excerpt, :status, :featured_image, :view_count, :published_at)
  end
end
