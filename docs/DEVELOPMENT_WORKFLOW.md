# API開発ワークフロー手順書

## 概要

このドキュメントでは、共有DBスキーマを利用したAPI開発の標準的なワークフローを定義します。

## アーキテクチャ概要

```
┌─────────────────┐    ┌─────────────────┐
│  Schema Team    │    │   API Team      │
│  (test-db-schema)│   │(test-api-schema)│
├─────────────────┤    ├─────────────────┤
│ - Schema定義     │    │ - Rails Models  │
│ - sqldef管理    │◄──►│ - API Controllers│
│ - Migration     │    │ - Business Logic│
└─────────────────┘    └─────────────────┘
           │                     │
           └──────┬──────────────┘
                  ▼
        ┌─────────────────┐
        │  Shared Database │
        │    (MySQL)       │
        └─────────────────┘
```

## 1. 共有DBスキーマ変更時の手順

### 1.1 Schema Team側の作業

#### ブランチ作成
```bash
cd test-db-schema
git checkout master
git pull origin master
git checkout -b feature/add-new-table
```

#### スキーマ変更
1. `schemas/parts/01_tables.sql` - 新しいテーブル定義を追加
2. `schemas/parts/02_constraints.sql` - 外部キー制約を追加
3. 適切なインデックスを設定

#### 変更例（commentsテーブル追加）
```sql
-- schemas/parts/01_tables.sql
CREATE TABLE comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NULL,
    parent_id BIGINT UNSIGNED NULL,
    author_name VARCHAR(100),
    author_email VARCHAR(255),
    content TEXT NOT NULL,
    status ENUM('pending', 'approved', 'spam', 'trash') NOT NULL DEFAULT 'pending',
    is_approved BOOL NOT NULL DEFAULT FALSE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_comments_post_id (post_id),
    INDEX idx_comments_user_id (user_id),
    INDEX idx_comments_parent_id (parent_id),
    INDEX idx_comments_status (status),
    INDEX idx_comments_is_approved (is_approved),
    INDEX idx_comments_created_at (created_at)
);
```

```sql
-- schemas/parts/02_constraints.sql
ALTER TABLE comments 
ADD CONSTRAINT fk_comments_post_id 
FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE;

ALTER TABLE comments 
ADD CONSTRAINT fk_comments_user_id 
FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE comments 
ADD CONSTRAINT fk_comments_parent_id 
FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE;
```

#### スキーマ検証
```bash
# データベース起動
docker compose up -d

# スキーマ適用テスト（dry-run）
./scripts/apply-schema.sh --config configs/local.env --dry-run

# 問題なければ実際に適用
./scripts/apply-schema.sh --config configs/local.env
```

#### コミット・プッシュ
```bash
git add .
git commit -m "feat: Add comments table for post commenting functionality

- Added comments table with support for:
  - Registered user comments (user_id)
  - Anonymous comments (author_name, author_email)
  - Nested comments (parent_id for replies)
  - Comment status management (pending, approved, spam, trash)
  - IP tracking for moderation
  - Proper indexing for performance

Breaking Changes: None
Migration Required: Yes - New table creation
API Impact: Requires Comment model and API endpoints implementation"

git push origin feature/add-new-table
```

#### プルリクエスト作成
GitHub上でプルリクエストを作成し、以下を含める：
- 変更の概要
- 影響範囲の説明
- Breaking Changesの有無
- APIチームへの影響説明
- 移行手順

### 1.2 API Team側の作業

#### スキーマ変更の取り込み

```bash
cd test-api-schema-sqldef
git checkout main
git pull origin main
git checkout -b feature/implement-comments-api

# サブモジュールを最新に更新
git submodule update --remote

# 新しいスキーマを適用
docker compose --profile migration up schema-migration
```

#### Rails Model・Controller生成

```bash
# モデル生成（--skip-migration は重要！）
docker compose run --rm rails bin/rails generate model Comment \
  post:references user:references parent:references \
  author_name:string author_email:string content:text \
  status:string is_approved:boolean ip_address:string \
  user_agent:text --skip-migration

# APIコントローラ生成
docker compose run --rm rails bin/rails generate controller Api::V1::Comments \
  index show create update destroy --skip-routes
```

#### モデル関連付け設定

```ruby
# app/models/comment.rb
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
  
  private
  
  def anonymous_comment?
    user_id.nil?
  end
end

# 既存モデルにも関連付け追加
# app/models/post.rb
has_many :comments, dependent: :destroy

# app/models/user.rb  
has_many :comments, dependent: :destroy
```

#### APIコントローラ実装

```ruby
# app/controllers/api/v1/comments_controller.rb
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
  
  private
  
  def comment_params
    params.require(:comment).permit(:post_id, :user_id, :parent_id, :author_name, :author_email, :content, :status, :is_approved)
  end
end
```

#### ルーティング設定

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :posts do
        resources :comments, only: [:index, :create]  # 投稿別コメント
      end
      
      resources :comments, only: [:index, :show, :create, :update, :destroy]  # 汎用コメント
    end
  end
end
```

#### テストデータ更新

```ruby
# db/seeds.rb
# サンプルコメントデータを追加
comments = [
  {
    post: rails_post,
    user: jane,
    content: "Great article!",
    status: "approved",
    is_approved: true
  }
]
```

#### テスト・検証

```bash
# シードデータ更新
docker compose run --rm rails bin/rails db:seed

# Rails起動
docker compose up rails

# API動作確認
curl http://localhost:3000/api/v1/comments
curl http://localhost:3000/api/v1/posts/1/comments

# 新規コメント作成テスト
curl -X POST http://localhost:3000/api/v1/comments \
  -H "Content-Type: application/json" \
  -d '{"comment": {"post_id": 1, "content": "Test comment"}}'
```

## 2. 定期的な保守作業

### 2.1 スキーマ同期確認
```bash
# 週1回実行推奨
git submodule update --remote
git status  # サブモジュール変更があるかチェック
```

### 2.2 データベースバックアップ
```bash
# 重要な変更前に実行
./db-schema/scripts/backup-database.sh --config configs/production.env
```

## 3. 開発環境のセットアップ

### 3.1 新しい開発者向け

```bash
# リポジトリクローン
git clone --recursive https://github.com/fqqk/test-api-schema-sqldef.git
cd test-api-schema-sqldef

# 環境構築
docker compose build
docker compose --profile migration up schema-migration
docker compose run --rm rails bin/rails db:seed
```

## 4. トラブルシューティング

### 4.1 スキーマ適用エラー
```bash
# バックアップから復元
./db-schema/scripts/restore-database.sh backups/backup_YYYYMMDD_HHMMSS.sql

# 手動でスキーマを確認
docker compose exec mysql mysql -u testuser -ptestpass testdb
```

### 4.2 サブモジュール同期問題
```bash
# サブモジュールを強制更新
git submodule update --init --recursive --force
```

## 5. 開発のベストプラクティス

### 5.1 命名規則
- ブランチ名: `feature/add-table-name` or `feature/implement-api-name`
- コミットメッセージ: [Conventional Commits](https://www.conventionalcommits.org/ja/) に従う
- テーブル名: 複数形、snake_case
- API エンドポイント: RESTful設計に従う

### 5.2 安全な開発
1. 必ず `--dry-run` でスキーマ変更をテスト
2. 本番環境変更前にバックアップ取得
3. Breaking Changes は事前にチーム間で調整
4. ロールバック手順を事前に確認

### 5.3 コードレビューポイント
- スキーマ変更の必要性と設計
- インデックスの適切性
- 外部キー制約の整合性
- APIの設計（RESTful）
- バリデーションの適切性
- セキュリティ観点（SQLインジェクション対策等）

---

## 関連ドキュメント
- [Schema Management Guide](../test-db-schema/docs/SCHEMA_MANAGEMENT.md)
- [API Design Guidelines](./docs/API_GUIDELINES.md)
- [Deployment Guide](./docs/DEPLOYMENT.md)