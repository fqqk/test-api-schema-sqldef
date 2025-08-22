class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user, optional: true
  belongs_to :parent, class_name: 'Comment', optional: true
  
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_id', dependent: :destroy
  
  validates :content, presence: true, length: { minimum: 1, maximum: 1000 }
  validates :status, inclusion: { in: %w[pending approved spam trash] }
  validates :author_name, presence: true, if: :anonymous_comment?
  validates :author_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, if: :anonymous_comment?
  
  scope :approved, -> { where(is_approved: true) }
  scope :pending, -> { where(status: 'pending') }
  scope :by_post, ->(post_id) { where(post_id: post_id) }
  scope :top_level, -> { where(parent_id: nil) }
  scope :replies_to, ->(comment_id) { where(parent_id: comment_id) }
  
  before_save :set_approval_status
  
  private
  
  def anonymous_comment?
    user_id.nil?
  end
  
  def set_approval_status
    self.is_approved = (status == 'approved')
  end
end
