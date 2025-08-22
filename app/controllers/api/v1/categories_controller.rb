class Api::V1::CategoriesController < ApplicationController
  before_action :set_category, only: [:show, :update, :destroy]
  
  def index
    @categories = Category.includes(:parent, :children).all
    render json: @categories, include: [:parent, :children]
  end

  def show
    render json: @category, include: [:parent, :children, :posts]
  end

  def create
    @category = Category.new(category_params)
    
    if @category.save
      render json: @category, status: :created
    else
      render json: { errors: @category.errors }, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      render json: @category
    else
      render json: { errors: @category.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    head :no_content
  end
  
  private
  
  def set_category
    @category = Category.find(params[:id])
  end
  
  def category_params
    params.require(:category).permit(:name, :slug, :description, :parent_id, :sort_order, :is_active)
  end
end
