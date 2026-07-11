-- ========================================================
-- 1. カスタム型 ＆ 予約語テーブル定義
-- ========================================================
CREATE TYPE adventurer_log_type_t AS ENUM ('profile_update', 'ban', 'unban', 'force_mutation');

-- ④ 予約語マスタテーブル（運営用の文字列を保護）
CREATE TABLE reserved_user_names (
    name VARCHAR(30) PRIMARY KEY
);

-- 予約語の初期データ投入例（LOWERで統一して格納）
INSERT INTO reserved_user_names (name) VALUES 
('admin'), ('administrator'), ('root'), ('system'), ('support'), ('help'), ('api');

-- ========================================================
-- 2. メインテーブル定義
-- ========================================================

-- adventurers（冒険者基本）テーブル
CREATE TABLE adventurers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    virtual_name VARCHAR(50) NOT NULL, -- ③ 世界観重視のため50文字へ拡張（英数字制限解除）
    user_name VARCHAR(30) NOT NULL,    -- ＠アクセスのための識別子
    display_name VARCHAR(50) NOT NULL, -- 画面表示名
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ,            -- ⑦ 個人開発初期には過剰だが、美しいので残存
    banned_at TIMESTAMPTZ              
);

-- ⑤ 監査ログテーブル（BAN理由等はここに必須保存されるため、本体へのカラム追加は不要）
CREATE TABLE adventurer_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    operator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    target_id UUID REFERENCES adventurers(id) ON DELETE CASCADE,
    log_type adventurer_log_type_t NOT NULL,
    reason TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb NOT NULL
);

-- ========================================================
-- 3. 強力な DB レベル制約 ＆ インデックス
-- ========================================================

-- ① user_name のフォーマット制約
ALTER TABLE adventurers ADD CONSTRAINT chk_adventurers_user_name_format 
CHECK (user_name ~ '^[a-zA-Z0-9_-]{3,30}$');

-- ② display_name / virtual_name の「全角スペース・空白のみ」を完全に排除する制約
ALTER TABLE adventurers ADD CONSTRAINT chk_adventurers_display_name_blank
CHECK (length(regexp_replace(display_name, '[\s ]+', '', 'g')) > 0);

ALTER TABLE adventurers ADD CONSTRAINT chk_adventurers_virtual_name_blank
CHECK (length(regexp_replace(virtual_name, '[\s ]+', '', 'g')) > 0);

-- ユニークインデックス（大文字小文字・前後スペースを無視）
CREATE UNIQUE INDEX adventurers_virtual_name_lower_uq ON adventurers (LOWER(TRIM(both '  ' from virtual_name)));
CREATE UNIQUE INDEX adventurers_user_name_lower_uq ON adventurers (LOWER(TRIM(user_name)));

-- 検索最適化インデックス（⑥ ORDER BY updated_at 用のインデックスを追加）
CREATE INDEX idx_adventurers_lifecycle_updated ON adventurers(updated_at DESC) WHERE deleted_at IS NULL AND banned_at IS NULL;
CREATE INDEX idx_adventurer_logs_target ON adventurer_logs(target_id);

-- ========================================================
-- 4. RLS ポリシー定義
-- ========================================================
ALTER TABLE adventurers ENABLE ROW LEVEL SECURITY;
ALTER TABLE adventurers FORCE ROW LEVEL SECURITY;
ALTER TABLE adventurer_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE adventurer_logs FORCE ROW LEVEL SECURITY;

-- [adventurers]
CREATE POLICY adventurers_select ON adventurers FOR SELECT USING (
  (deleted_at IS NULL AND banned_at IS NULL) OR auth.uid() = id OR (auth.jwt() ->> 'role' = 'admin')
);
CREATE POLICY adventurers_insert ON adventurers FOR INSERT WITH CHECK (
  auth.uid() = id OR (auth.role() = 'service_role')
);
CREATE POLICY adventurers_update ON adventurers FOR UPDATE USING (
  (auth.uid() = id AND banned_at IS NULL) OR (auth.jwt() ->> 'role' = 'admin') OR (auth.role() = 'service_role')
) WITH CHECK (
  (auth.uid() = id AND banned_at IS NULL) OR (auth.jwt() ->> 'role' = 'admin') OR (auth.role() = 'service_role')
);

-- [adventurer_logs]
CREATE POLICY logs_select ON adventurer_logs FOR SELECT USING (
  (auth.jwt() ->> 'role' = 'admin') OR (auth.role() = 'service_role')
);

-- ========================================================
-- 5. トリガー関数（予約語チェック内包）
-- ========================================================

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION update_adventurers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_adventurers_updated_at BEFORE UPDATE ON adventurers FOR EACH ROW EXECUTE FUNCTION update_adventurers_updated_at();


-- 作成時ガード ＆ 予約語チェック
CREATE OR REPLACE FUNCTION prepare_adventurers_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.role() = 'authenticated' THEN
    NEW.id := auth.uid();
  END IF;
  
  -- ④ 予約語の重複チェック
  IF EXISTS (SELECT 1 FROM reserved_user_names WHERE name = LOWER(TRIM(NEW.user_name))) THEN
    RAISE EXCEPTION '指定されたユーザーIDはシステムによって予約されています。';
  END IF;
  
  NEW.deleted_at := NULL;
  NEW.banned_at := NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prepare_adventurers_insert BEFORE INSERT ON adventurers FOR EACH ROW EXECUTE FUNCTION prepare_adventurers_insert();


-- 永久固定ガード ＆ 更新時予約語チェック
CREATE OR REPLACE FUNCTION guard_adventurers_update()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.role() = 'authenticated' THEN
    -- ④ user_name 変更時も予約語をガード
    IF NEW.user_name <> OLD.user_name THEN
      IF EXISTS (SELECT 1 FROM reserved_user_names WHERE name = LOWER(TRIM(NEW.user_name))) THEN
        RAISE EXCEPTION '指定されたユーザーIDはシステムによって予約されています。';
      END IF;
    END IF;

    -- 主要識別子・ステータスの固定
    NEW.id := OLD.id;
    NEW.virtual_name := OLD.virtual_name;
    NEW.banned_at := OLD.banned_at;
    NEW.deleted_at := OLD.deleted_at;

    -- フリーズ制御
    IF OLD.deleted_at IS NOT NULL OR OLD.banned_at IS NOT NULL THEN
      NEW.user_name := OLD.user_name;
      NEW.display_name := OLD.display_name;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_adventurers_update BEFORE UPDATE ON adventurers FOR EACH ROW EXECUTE FUNCTION guard_adventurers_update();

CREATE OR REPLACE FUNCTION prepare_adventurers_insert()
RETURNS TRIGGER AS $$
BEGIN
  -- 【削除】NEW.id := auth.uid(); はバグとロックの元なので削除。
  -- 代わりに、Next.js（アプリ側）から渡された NEW.id が、
  -- RLS（auth.uid() = id）によって自動的に検証されるため安全です。
  
  -- ④ 予約語の重複チェック
  IF EXISTS (SELECT 1 FROM reserved_user_names WHERE name = LOWER(TRIM(NEW.user_name))) THEN
    RAISE EXCEPTION '指定されたユーザーIDはシステムによって予約されています。';
  END IF;
  
  NEW.deleted_at := NULL;
  NEW.banned_at := NULL;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;