class Category < ApplicationRecord
  belongs_to :parent, class_name: 'Category', optional: true
  has_many :children, class_name: 'Category', foreign_key: 'parent_id', dependent: :destroy
  
  has_many :post_categories, dependent: :destroy
  has_many :posts, through: :post_categories
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
