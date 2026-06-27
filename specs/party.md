# party spec（ユーザー管理機能）  

作成者：ブタメロン  
作成日：2026/6/20  

# ■ ディレクトリ  

party パーティ管理モジュール  

# ■ 目的  

パーティ管理を行うモジュール

主な用途  

- アプリケーションユーザー管理  

# ■　考え方

基本的にユーザーコミュニケーションを行うための箱のようなもの。
パーティは解散しても、解散済みパーティ（記録簿）としてパーティメンバーとのコミュニティは
一生残るものとする。（フレンド機能がないため、再度連絡できるように）

人数で扱いが昇格する。
10人未満　← 小規模パーティ
50人未満 ←　中規模パーティ
500人未満 ← 大規模パーティ
501人以上 ←　超大型パーティ



# ■ 機能概要  

- パーティ募集掲示板 // square
- パーティタグ整備　// 検索用
- パーティ専用掲示板 // フレンドとはまた別の制限
- パーティロール管理
- パーティ検索機能

※掲示板はすべてsquare。パーティに所属するメンバーのみ閲覧可能なSquareを利用する。  

# ■機能詳細

## パーティ募集掲示板  
パーティメンバーを募集する掲示板。新規掲載・上位表示（バンプ機能）は週1回、内容の編集はいつでも可能

## ロール管理  
- リーダー　・・・　パーティメンバーの脱退権、警告権、パーティ紹介文編集権限、サブリーダーの解除権限、カスタムロール作成権限
- サブリーダー　・・・　パーティメンバーの脱退権・承認権、警告権、パーティ紹介文編集権限、カスタムロール作成権限
- メンバーロール　・・・　参加のみ

※ただし、サブリーダー以上の全員の承認がないとメンバー脱退はできない  
※今後、表示掲示板などはロール毎に本当のロール管理設定可能とします  
※リーダー、サブリーダーはカスタムロールを作成可能とします  

## パーティ専用掲示板
パーティタブより、パーティ専用の掲示板を開くことができる機能。  

## パーティ検索機能
タグ検索や紹介文検索が可能。SEOっぽい欄とタグは分ける

## パーティ作成条件・存続条件
- １人以上のリーダーが居る状態で、３人以上のメンバーが存在する場合に作成可能
  ※1人で作成は可能だが、1週間以内に3人以上集まらなければ削除
  ※2人で作成できないのは、1対1だと作成する意味がないからｗ
- ２人以下になったら１カ月で強制削除
- リーダーが脱退した場合、もしくはアカウント削除や停止処分の場合はサブリーダーに権限譲渡  
  サブリーダーが存在しない場合は、退会時に選択、もしくはメンバーが選任可能  
  一か月以内に選任されない場合は強制削除
-  リーダーが1カ月以上アクセスが無い場合は強制退任。メンバーが誰一人1カ月以上アクセスが無い場合は
　　パーティ強制削除。

# ■ 関連テーブル一覧  

- party
- party_adventurers
- party_rolls
- party_tags

# ■ 関連テーブル仕様  

### party
* id BIGINT パリティーID（主キー）  
* name VARCHAR(255) パーティ名  
* description TEXT パーティ紹介文  
* seo_keywords VARCHAR(255) SEO用キーワード欄  
* member_count INT 現在の所属メンバー数（存続条件チェック用）  
* last_activity_at DATETIME メンバー全員の最終アクセス日時（強制削除判定用）  
* last_bumped_at DATETIME 最終バンプ（上位表示）日時（週1回制限のチェック用）  
* created_at DATETIME 作成日時  
* updated_at DATETIME 更新日時  

### party_adventurers
* id BIGINT メンバー管理ID（主キー）  
* party_id BIGINT パーティID（外部キー）  
* user_id BIGINT ユーザーID（外部キー）  
* custom_role_id BIGINT カスタムロールID（外部キー）  
* is_leader BOOLEAN リーダー権限フラグ（1:リーダー, 0:その他）  
* is_sub_leader BOOLEAN サブリーダー権限フラグ（1:サブリーダー, 0:その他）  
* warning_count INT 警告回数  
* last_login_at DATETIME 該当ユーザーの最終アクセス日時（リーダーの1ヶ月未アクセス判定等用）  
* joined_at DATETIME パーティ加入日時  

### party_rolls
* id BIGINT ロールID（主キー）  
* party_id BIGINT パーティID（外部キー）  
* role_name VARCHAR(100) ロール名（カスタムロール用）  
* can_kick BOOLEAN メンバー脱退権限フラグ  
* can_warn BOOLEAN 警告権限フラグ  
* can_edit_desc BOOLEAN 紹介文編集権限フラグ  
* can_manage_sub BOOLEAN サブリーダー解除権限フラグ  
* can_create_role BOOLEAN カスタムロール作成権限フラグ  
* can_approve BOOLEAN メンバー承認権限フラグ  
* created_at DATETIME 作成日時  

### party_tags
* id BIGINT タグID（主キー）  
* tag_name VARCHAR(50) タグ名（重複不可、検索用）  

### party_tag_relations
* party_id BIGINT パーティID（複合主キー / 外部キー）  
* tag_id BIGINT タグID（複合主キー / 外部キー）  

### party_kick_approvals
* id BIGINT 承認リクエストID（主キー）  
* party_id BIGINT パーティID（外部キー）  
* target_user_id BIGINT 脱退対象のユーザーID  
* requested_user_id BIGINT 発議したリーダー/サブリーダーのID  
* approved_managers JSON 承認したサブリーダー以上のユーザーID配列  
* is_executed BOOLEAN 脱退処理が実行済みかどうかのフラグ  
* created_at DATETIME 発議日時