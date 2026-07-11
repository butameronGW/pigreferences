-- ========================================================
-- 1. カスタム型 ＆ テーブル定義
-- ========================================================

-- ステータス用カスタム型
CREATE TYPE square_status_t AS ENUM ('pending', 'published', 'rejected');

-- 通報の種類
CREATE TYPE report_type_t AS ENUM ('spam', 'harassment', 'copyright', 'other');

-- ログの種類
CREATE TYPE log_type_t AS ENUM ('report', 'moderation', 'other');

-- square（文書データ）テーブル
CREATE TABLE square (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  parent_id UUID REFERENCES square(id) ON DELETE SET NULL, -- 自己参照で無限ツリー
  content TEXT NOT NULL,
  status square_status_t DEFAULT 'pending' NOT NULL, -- 初期値は未審査
  risk_level JSONB DEFAULT '{}'::jsonb, -- OpenAIの判定スコア用
  report_count INT DEFAULT 0 NOT NULL,
  deleted_at TIMESTAMPTZ -- 値があれば論理削除
);

-- tags（タグマスター）テーブル
CREATE TABLE tags (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(50) NOT NULL
);

-- square_tags（掲示板・タグ中間テーブル）
CREATE TABLE square_tags (
  square_id UUID NOT NULL REFERENCES square(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (square_id, tag_id)
);

-- square_likes（いいねデータ）
CREATE TABLE square_likes (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  square_id UUID NOT NULL REFERENCES square(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (user_id, square_id)
);

-- square_reports（通報データ）
CREATE TABLE square_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  square_id UUID NOT NULL REFERENCES square(id) ON DELETE CASCADE,
  report_type report_type_t DEFAULT 'other' NOT NULL,
  reason_details TEXT
);

-- square_logs（汎用ログテーブル）
CREATE TABLE square_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  square_id UUID NOT NULL REFERENCES square(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  log_type log_type_t DEFAULT 'other' NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb NOT NULL
);

-- ========================================================
-- 2. 制約 (Constraints) ＆ インデックス (Indexes)
-- ========================================================

-- ① 空文字タグの禁止
ALTER TABLE tags ADD CONSTRAINT chk_tags_name CHECK (length(trim(name)) > 0);

-- ② 自分自身へのリプライ（無限ループ）禁止
ALTER TABLE square ADD CONSTRAINT chk_square_parent CHECK (parent_id IS NULL OR parent_id <> id);

-- 投稿サイズ制限
ALTER TABLE square ADD CONSTRAINT chk_square_content_length CHECK (char_length(content) <= 10000);

-- 通報重複禁止
ALTER TABLE square_reports ADD CONSTRAINT uq_square_reports UNIQUE (user_id, square_id);

-- タグユニークインデックス（大文字小文字・前後の空白を無視）
CREATE UNIQUE INDEX tags_name_lower_uq ON tags (LOWER(TRIM(name)));

-- 検索最適化インデックス
CREATE INDEX idx_square_parent_id ON square(parent_id);
CREATE INDEX idx_square_created_at ON square(created_at DESC);
CREATE INDEX idx_square_status ON square(status);
CREATE INDEX idx_square_deleted_at ON square(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_square_likes_square_id ON square_likes(square_id);
CREATE INDEX idx_square_reports_square_id ON square_reports(square_id);

-- ========================================================
-- 3. トリガー関数定義
-- ========================================================

-- updated_at自動更新トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_square_updated_at BEFORE UPDATE ON square FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- 投稿作成ガード (user_id強制、メタデータ初期化)
CREATE OR REPLACE FUNCTION prepare_square_insert()
RETURNS TRIGGER AS $$
BEGIN
  NEW.user_id := auth.uid();
  NEW.status := 'pending';
  NEW.report_count := 0;
  NEW.risk_level := '{}'::jsonb;
  NEW.deleted_at := NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prepare_square_insert BEFORE INSERT ON square FOR EACH ROW EXECUTE FUNCTION prepare_square_insert();


-- ⑤ 通報時、対象投稿の report_count を自動インクリメントするトリガー
-- ※他人の投稿も更新できるよう、特権権限（SECURITY DEFINER）で実行
CREATE OR REPLACE FUNCTION increment_square_report_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE square
  SET report_count = report_count + 1
  WHERE id = NEW.square_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_increment_report_count AFTER INSERT ON square_reports FOR EACH ROW EXECUTE FUNCTION increment_square_report_count();


-- 更新ガード（システムカラム保護 ＆ 削除後フリーズ ＆ 復元禁止）
CREATE OR REPLACE FUNCTION guard_square_system_columns()
RETURNS TRIGGER AS $$
BEGIN
  -- 一般ログインユーザー（authenticated）の直接更新からシステム項目をガード
  IF auth.role() = 'authenticated' THEN
    NEW.status := OLD.status;
    NEW.risk_level := OLD.risk_level;
    NEW.user_id := OLD.user_id;

    -- 通報トリガーによる正当な「+1」のみ通し、ユーザーによる直接の数値改ざんは戻す
    IF NEW.report_count <> OLD.report_count + 1 THEN
      NEW.report_count := OLD.report_count;
    END IF;
  END IF;

  -- 削除済み投稿のライフサイクル制御（Reddit風フリーズ）
  IF OLD.deleted_at IS NOT NULL THEN
    NEW.deleted_at := OLD.deleted_at; -- 復元禁止
    NEW.content := OLD.content;       -- 削除後の内容編集を禁止
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_square BEFORE UPDATE ON square FOR EACH ROW EXECUTE FUNCTION guard_square_system_columns();

-- ========================================================
-- 4. RLS 有効化 ＆ 強制適用 (ENABLE & FORCE RLS)
-- ========================================================
DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);
    END LOOP;
END $$;

-- ========================================================
-- 5. RLS ポリシー定義
-- ========================================================

-- [square]
-- ⑧ 将来を見据え、運営アカウント（role = admin）用のバイパスルートを開通
CREATE POLICY square_select ON square FOR SELECT USING (
  (status = 'published' AND deleted_at IS NULL)
  OR auth.uid() = user_id
  OR (auth.jwt() ->> 'role' = 'admin')
);

CREATE POLICY square_insert ON square FOR INSERT WITH CHECK (true);
CREATE POLICY square_update ON square FOR UPDATE USING (auth.uid() = user_id);

-- [square_likes]
CREATE POLICY likes_select ON square_likes FOR SELECT USING (true);

-- ④ 未公開（pending）や削除済み投稿への不正いいねをRSLでガード
CREATE POLICY likes_insert ON square_likes FOR INSERT WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM square s
    WHERE s.id = square_likes.square_id
      AND s.status = 'published'
      AND s.deleted_at IS NULL
  )
);

CREATE POLICY likes_delete ON square_likes FOR DELETE USING (auth.uid() = user_id);

-- [square_reports]
-- ③ すでに論理削除された投稿に対する「死体蹴り通報」をポリシーレベルで遮断
CREATE POLICY reports_insert ON square_reports FOR INSERT WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM square s
    WHERE s.id = square_reports.square_id
      AND s.deleted_at IS NULL
  )
);

CREATE POLICY reports_select ON square_reports FOR SELECT USING (auth.uid() = user_id);

-- [square_tags]
-- 中間テーブルの参照を明示化し、自分の投稿のタグだけを操作可能に制限
CREATE POLICY tags_insert ON square_tags FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM square s WHERE s.id = square_tags.square_id AND s.user_id = auth.uid())
);

CREATE POLICY tags_delete ON square_tags FOR DELETE USING (
  EXISTS (SELECT 1 FROM square s WHERE s.id = square_tags.square_id AND s.user_id = auth.uid())
);

-- [tags]
CREATE POLICY tags_select ON tags FOR SELECT USING (true);

-- [square_logs] 
-- ポリシーなし（完全閉鎖。一般ユーザーのアクセスは0件、service_roleのみ）