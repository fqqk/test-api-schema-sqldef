#!/bin/bash
set -e

echo "🚀 Rails 8 API with Shared DB Schema Setup"
echo "==========================================="

# Step 1: Start MySQL
echo "📦 Step 1: Starting MySQL..."
docker compose up -d mysql

# Step 2: Wait for MySQL and apply schema
echo "📦 Step 2: Applying database schema..."
sleep 15  # Wait for MySQL to be ready
docker compose --profile migration up schema-migration

# Step 3: Generate Rails models (without migrations since we use shared schema)
echo "📦 Step 3: Generating Rails models..."
docker compose run --rm rails bash -c "
  # Create models to match the shared schema  
  bin/rails generate model User email:string name:string password_hash:string email_verified_at:datetime status:string --skip-migration
  bin/rails generate model Category name:string slug:string description:text parent:references sort_order:integer is_active:boolean --skip-migration  
  bin/rails generate model Post user:references title:string slug:string content:text excerpt:string status:string featured_image:string view_count:integer published_at:datetime --skip-migration
  bin/rails generate model PostCategory post:references category:references --skip-migration

  # Generate API controllers
  bin/rails generate controller Api::V1::Users index show create update destroy --skip-routes
  bin/rails generate controller Api::V1::Posts index show create update destroy --skip-routes
  bin/rails generate controller Api::V1::Categories index show create update destroy --skip-routes

  echo '✅ Models and controllers generated!'
"

# Step 4: Update Rails configuration
echo "📦 Step 4: Configuring Rails routes..."
cat > config/routes.rb << 'EOF'
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users, only: [:index, :show, :create, :update, :destroy] do
        resources :posts, only: [:index, :show, :create, :update, :destroy]
      end
      
      resources :posts, only: [:index, :show, :create, :update, :destroy] do
        member do
          patch :publish
          patch :unpublish
        end
      end
      
      resources :categories, only: [:index, :show, :create, :update, :destroy]
    end
  end
  
  # Health check endpoint (already exists in Rails 8)
  get "up" => "rails/health#show", as: :rails_health_check
end
EOF

echo "==========================================="
echo "✅ Setup complete!"
echo ""
echo "🔍 You can now start the Rails 8 API with:"
echo "   docker compose up rails"
echo ""
echo "📖 API endpoints will be available at:"
echo "   http://localhost:3000/api/v1/users"
echo "   http://localhost:3000/api/v1/posts"  
echo "   http://localhost:3000/api/v1/categories"
echo "   http://localhost:3000/up (health check)"