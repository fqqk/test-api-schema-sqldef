class Post < ApplicationRecord
  belongs_to :user
  
  has_many :post_categories, dependent: :destroy
  has_many :categories, through: :post_categories
  has_many :comments, dependent: :destroy
  
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }
  
  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
end
