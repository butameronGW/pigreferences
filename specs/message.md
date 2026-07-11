# message Spec（メッセージ機能）

作成者：ブタメロン
作成日：2026/6/28

# ■ ディレクトリ

メッセージモジュール

# ■ 目的

ユーザー同士の1対1コミュニケーションを管理するモジュール。

## 主な用途

* テキストメッセージ送信。
* 絵文字送信。
* リアルタイム更新。
* システム通知の受信。
* ユーザー通知の受信。
* メッセージ承認管理。

本アプリでは「フレンド」の概念は持たない。

ユーザーへ初回メッセージを送信する場合は、送信リクエストを送る。

相手が承認した場合のみ、その後自由にメッセージを送信できる。

これにより迷惑メッセージを防止しつつ、実質的なフレンド機能を実現する。

# ■ 基本仕様

* 1対1メッセージのみ対応する。
* パーティチャット・ギルドチャットとは別モジュールで管理する。
* メッセージはリアルタイム更新する。
* システム通知も同一モジュールで管理する。
* システム通知は削除不可とする。
* 通知種別によって表示方法を切り替える。

# ■ 機能概要

## メッセージ機能

* メッセージ送信。
* メッセージ受信。
* 絵文字送信。
* メッセージ削除。
* 送信取消（一定時間以内を想定）。
* 未読管理。
* 既読管理。
* リアルタイム更新。


## メッセージ承認機能

* メッセージ送信リクエスト。
* 承認。
* 拒否。
* 承認済みユーザー検索。
* 承認解除。
* ミュート機能。
* 通報機能。

## 通知機能

* システム通知。
* 運営通知。
* ユーザー通知。
* お知らせ通知。
* メッセージ検索。

# ■ システム通知

システム通知は運営から送信される通知である。

例

* パーティ参加承認。
* パーティ招待。
* 依頼成立。
* 評価完了。
* レベルアップ。
* 運営からのお知らせ。

システム通知は削除不可とする。

# ■ 将来拡張予定

以下の機能追加を想定する。

* 画像送信。
* ファイル送信。

# ■ 関連テーブル一覧

* messages // メッセージデータそのもの
* message_contacts // 通信確立情報。ユーザーの申請、承認、拒否管理
* announcement_reads // 管理者通知を１本にしたいので、既読未読管理用に追加する。
　　　　　　　　　　なお、パーティ通知なども管理可能とする。
* announcements //　お知らせ機能


# ■ モジュール概要

* ユーザー同士の1対1メッセージを管理する。
* 初回メッセージは承認制とする。
* 承認後は自由にメッセージを送信できる。
* システム通知・ユーザー通知を同一モジュールで管理する。
* パーティチャット・ギルドチャットとは独立したモジュールとする。
* リアルタイム更新を前提とする。


-- ===========================================
-- メッセージ通信管理
-- ===========================================
CREATE TABLE message_contacts (

    id                  BIGSERIAL PRIMARY KEY,     -- 通信ID

    requester_id        UUID NOT NULL,             -- メッセージ送信を申請したユーザー
    receiver_id         UUID NOT NULL,             -- 申請を受けたユーザー

    status              SMALLINT NOT NULL,         -- 0:申請中 1:承認 2:拒否

    requested_at        TIMESTAMP NOT NULL,        -- 申請日時
    approved_at         TIMESTAMP,                 -- 承認日時
    rejected_at         TIMESTAMP,                 -- 拒否日時

    created_at          TIMESTAMP NOT NULL,
    updated_at          TIMESTAMP NOT NULL

);
-- ===========================================
-- メッセージ
-- ===========================================
CREATE TABLE messages (

    id                  BIGSERIAL PRIMARY KEY,     -- メッセージID

    contact_id          BIGINT NOT NULL,           -- 通信ID（message_contacts.id）

    sender_id           UUID NOT NULL,             -- 送信者

    message_type        SMALLINT NOT NULL,         -- 0:テキスト 1:絵文字 2:システム通知

    content             TEXT NOT NULL,             -- メッセージ内容

    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE, -- 送信取消・論理削除

    created_at          TIMESTAMP NOT NULL,
    updated_at          TIMESTAMP NOT NULL

);
-- ===========================================
-- 全体お知らせ
-- ===========================================
CREATE TABLE announcements (

    id                  BIGSERIAL PRIMARY KEY,     -- お知らせID

    title               VARCHAR(200) NOT NULL,     -- タイトル

    content             TEXT NOT NULL,             -- お知らせ本文

    published_at        TIMESTAMP NOT NULL,        -- 公開日時

    created_at          TIMESTAMP NOT NULL,
    updated_at          TIMESTAMP NOT NULL

);
-- ===========================================
-- お知らせ既読管理
-- ===========================================
CREATE TABLE announcement_reads (

    announcement_id     BIGINT NOT NULL,           -- お知らせID

    adventure_id        UUID NOT NULL,             -- 閲覧ユーザー

    read_at             TIMESTAMP NOT NULL,        -- 既読日時

    PRIMARY KEY (
        announcement_id,
        adventure_id
    )

);
👍 私ならさらにこうします

message_contacts の status は将来を考えて少し余裕を持たせます。

0 : PENDING（申請中）
1 : APPROVED（承認）
2 : REJECTED（拒否）
3 : BLOCKED（ブロック）

そうすると 「承認解除」や「ブロック」 の機能を後から追加してもテーブルを増やさずに済みます。

あと、messages.sender_id は NULL を許可しないままで問題ありません。システム通知は「SYSTEM」という専用ユーザー（または運営ユーザー）を1件用意して送信者として扱う設計にすると、DMとシステム通知を同じロジックで扱えるので実装がシンプルになります。
