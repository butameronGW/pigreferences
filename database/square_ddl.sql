-- 1. ステータス用カスタム型の作成
CREATE TYPE square_status_t AS ENUM ('pending', 'published', 'rejected');

-- 2. square（文書データ）テーブル
CREATE TABLE square (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  parent_id UUID REFERENCES square(id) ON DELETE CASCADE, -- 自己参照で無限ツリー
  title VARCHAR(255), -- コメント（小文書）の場合は NULL を許容
  content TEXT NOT NULL,
  status square_status_t DEFAULT 'pending' NOT NULL,
  risk_level JSONB DEFAULT '{}'::jsonb, -- OpenAIの判定スコア用
  report_count INT DEFAULT 0 NOT NULL,
  deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL -- 値があれば論理削除
);

-- 3. tags（タグマスター）テーブル
CREATE TABLE tags (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);

-- 4. square_tags（掲示板・タグ中間テーブル）
CREATE TABLE square_tags (
  square_id UUID REFERENCES square(id) ON DELETE CASCADE,
  tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (square_id, tag_id)
);

-- 5. square_likes（いいねデータ）
CREATE TABLE square_likes (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  square_id UUID REFERENCES square(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  PRIMARY KEY (user_id, square_id)
);

-- 6. square_reports（通報データ）
CREATE TABLE square_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  square_id UUID REFERENCES square(id) ON DELETE CASCADE,
  report_type VARCHAR(50) NOT NULL,
  reason_details TEXT
);

-- 7. square_logs（汎用ログテーブル）
CREATE TABLE square_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  square_id UUID REFERENCES square(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  log_type VARCHAR(50) NOT NULL, -- 'report', 'moderation' など
  metadata JSONB DEFAULT '{}'::jsonb NOT NULL
);