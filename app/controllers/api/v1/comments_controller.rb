class Api::V1::CommentsController < ApplicationController
  before_action :set_comment, only: [:show, :update, :destroy]
  
  def index
    if params[:post_id]
      @comments = Comment.by_post(params[:post_id])
                        .includes(:user, :replies)
                        .top_level
                        .order(created_at: :desc)
    else
      @comments = Comment.includes(:user, :post, :replies).order(created_at: :desc)
    end
    
    render json: @comments, include: [:user, :replies]
  end

  def show
    render json: @comment, include: [:user, :post, :replies]
  end

  def create
    @comment = Comment.new(comment_params)
    @comment.ip_address = request.remote_ip
    @comment.user_agent = request.user_agent
    
    if @comment.save
      render json: @comment, status: :created, include: [:user, :post]
    else
      render json: { errors: @comment.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @comment.update(comment_params)
      render json: @comment, include: [:user, :post, :replies]
    else
      render json: { errors: @comment.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @comment.destroy
    head :no_content
  end
  
  private
  
  def set_comment
    @comment = Comment.find(params[:id])
  end
  
  def comment_params
    params.require(:comment).permit(:post_id, :user_id, :parent_id, :author_name, :author_email, :content, :status, :is_approved)
  end
end
