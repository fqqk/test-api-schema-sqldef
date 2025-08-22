# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Create sample users
users = [
  { email: "john@example.com", name: "John Doe", status: "active" },
  { email: "jane@example.com", name: "Jane Smith", status: "active" },
  { email: "bob@example.com", name: "Bob Wilson", status: "active" }
]

users.each do |user_attrs|
  user = User.find_or_create_by!(email: user_attrs[:email]) do |u|
    u.name = user_attrs[:name]
    u.status = user_attrs[:status]
    u.password_hash = "dummy_hash_for_development"
  end
  puts "✅ User: #{user.email}"
end

# Create sample categories
tech_category = Category.find_or_create_by!(slug: "technology") do |c|
  c.name = "Technology"
  c.description = "Articles about technology and programming"
  c.sort_order = 1
  c.is_active = true
end

rails_category = Category.find_or_create_by!(slug: "ruby-on-rails") do |c|
  c.name = "Ruby on Rails"
  c.description = "Ruby on Rails framework articles"
  c.parent = tech_category
  c.sort_order = 1
  c.is_active = true
end

js_category = Category.find_or_create_by!(slug: "javascript") do |c|
  c.name = "JavaScript"
  c.description = "JavaScript and web development"
  c.parent = tech_category
  c.sort_order = 2
  c.is_active = true
end

lifestyle_category = Category.find_or_create_by!(slug: "lifestyle") do |c|
  c.name = "Lifestyle"
  c.description = "Lifestyle and personal articles"
  c.sort_order = 2
  c.is_active = true
end

puts "✅ Categories created"

# Create sample posts
john = User.find_by(email: "john@example.com")
jane = User.find_by(email: "jane@example.com")
bob = User.find_by(email: "bob@example.com")

posts = [
  {
    user: john,
    title: "Getting Started with Rails 8",
    slug: "getting-started-rails-8",
    content: "Rails 8 brings many exciting features including built-in Docker support and improved performance...",
    excerpt: "Learn about the new features in Rails 8",
    status: "published",
    published_at: 1.week.ago,
    view_count: 150,
    categories: [rails_category]
  },
  {
    user: jane,
    title: "Modern JavaScript Best Practices",
    slug: "modern-javascript-best-practices",
    content: "In this article, we'll explore the latest JavaScript best practices for 2024...",
    excerpt: "Discover the latest JavaScript best practices",
    status: "published",
    published_at: 3.days.ago,
    view_count: 89,
    categories: [js_category]
  },
  {
    user: bob,
    title: "Work-Life Balance in Tech",
    slug: "work-life-balance-tech",
    content: "Maintaining work-life balance in the tech industry can be challenging...",
    excerpt: "Tips for maintaining work-life balance",
    status: "draft",
    view_count: 0,
    categories: [lifestyle_category]
  },
  {
    user: john,
    title: "Docker and Rails: A Perfect Match",
    slug: "docker-rails-perfect-match",
    content: "Docker containerization has revolutionized how we deploy and manage Rails applications...",
    excerpt: "Learn how Docker enhances Rails development",
    status: "published",
    published_at: 2.days.ago,
    view_count: 201,
    categories: [rails_category, tech_category]
  }
]

posts.each do |post_attrs|
  categories = post_attrs.delete(:categories)
  post = Post.find_or_create_by!(slug: post_attrs[:slug]) do |p|
    post_attrs.each { |key, value| p.send("#{key}=", value) }
  end
  
  # Associate categories
  categories.each do |category|
    PostCategory.find_or_create_by!(post: post, category: category)
  end
  
  puts "✅ Post: #{post.title}"
end

# Create sample comments
rails_post = Post.find_by(slug: "getting-started-rails-8")
js_post = Post.find_by(slug: "modern-javascript-best-practices")

comments = [
  {
    post: rails_post,
    user: jane,
    content: "Great article! Rails 8 really does make Docker integration so much easier.",
    status: "approved",
    is_approved: true
  },
  {
    post: rails_post,
    author_name: "Anonymous Developer",
    author_email: "dev@example.com",
    content: "Thanks for the detailed walkthrough. The Docker setup was exactly what I was looking for!",
    status: "approved",
    is_approved: true
  },
  {
    post: js_post,
    user: bob,
    content: "Solid advice on modern JavaScript. The async/await patterns you mentioned are game-changers.",
    status: "approved", 
    is_approved: true
  },
  {
    post: rails_post,
    user: john,
    content: "Glad you found it helpful! Rails 8 has really streamlined the development process.",
    status: "approved",
    is_approved: true
  }
]

comments.each do |comment_attrs|
  comment = Comment.find_or_create_by!(
    post: comment_attrs[:post], 
    content: comment_attrs[:content]
  ) do |c|
    comment_attrs.each { |key, value| c.send("#{key}=", value) unless key == :post }
  end
  puts "✅ Comment: #{comment.content[0..50]}..."
end

# Create a reply comment
parent_comment = Comment.first
if parent_comment
  reply = Comment.find_or_create_by!(
    post: parent_comment.post,
    parent: parent_comment,
    content: "I completely agree! The Docker integration is seamless."
  ) do |c|
    c.user = bob
    c.status = "approved"
    c.is_approved = true
  end
  puts "✅ Reply: #{reply.content[0..50]}..."
end

puts "🎉 Seeding completed!"
puts ""
puts "📊 Database Summary:"
puts "   Users: #{User.count}"
puts "   Categories: #{Category.count}"  
puts "   Posts: #{Post.count}"
puts "   Published Posts: #{Post.published.count}"
puts "   Comments: #{Comment.count}"
puts "   Approved Comments: #{Comment.approved.count}"
