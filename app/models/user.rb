class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :comments, dependent: :destroy
  
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true
end
