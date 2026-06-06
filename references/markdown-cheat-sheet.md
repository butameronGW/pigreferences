# Markdown チートシート

Markdown は「読みやすいテキストから文書を作るための記法」です。

---

# 見出し

```markdown
# 大見出し
## 中見出し
### 小見出し
```

表示例

# 大見出し

## 中見出し

### 小見出し

---

# 太字

```markdown
**太字**
```

表示例

**太字**

---

# 斜体

```markdown
*斜体*
```

表示例

*斜体*

---

# 引用

```markdown
> これは引用です
```

表示例

> これは引用です

---

# 番号付きリスト

```markdown
1. 要件定義
2. 設計
3. 開発
```

表示例

1. 要件定義
2. 設計
3. 開発

---

# 箇条書き

```markdown
- ログイン
- クエスト投稿
- クエスト応募
```

表示例

* ログイン
* クエスト投稿
* クエスト応募

---

# インラインコード

```markdown
`users`
```

表示例

`users`

---

# コードブロック

````markdown
```sql
SELECT *
FROM users;
```
````

表示例

```sql
SELECT *
FROM users;
```

---

# 区切り線

```markdown
---
```

表示例

---

---

# リンク

```markdown
[Google](https://www.google.com)
```

表示例

[Google](https://www.google.com)

---

# 画像

```markdown
![ロゴ](logo.png)
```

---

# 表

```markdown
| 項目 | 型 |
|------|----|
| id | uuid |
| name | text |
```

表示例

| 項目   | 型    |
| ---- | ---- |
| id   | uuid |
| name | text |

---

# 打ち消し線

```markdown
~~廃止予定機能~~
```

表示例

~~廃止予定機能~~

---

# タスクリスト

```markdown
- [x] Google認証
- [x] ユーザー登録
- [ ] クエスト投稿
- [ ] 評価機能
```

表示例

* [x] Google認証
* [x] ユーザー登録
* [ ] クエスト投稿
* [ ] 評価機能

---

# 絵文字

```markdown
🚀
⚔️
🐷
```

表示例

🚀 ⚔️ 🐷

---

# ハイライト（対応している環境のみ）

```markdown
==重要==
```

表示例

==重要==

---

# 上付き文字

```markdown
X^2^
```

表示例

X²

---

# 下付き文字

```markdown
H~2~O
```

表示例

H₂O

---

# ギルドワークスでよく使うテンプレ

## 機能仕様

```markdown
# クエスト投稿

## 目的

依頼者がクエストを登録する

## 入力項目

- タイトル
- 内容
- 報酬

## バリデーション

- タイトル必須
- 報酬0円不可
```

---

## ADR

```markdown
# ADR-001

## タイトル

Supabase Authを採用

## 背景

Google認証が必要

## 決定

Supabase Authを採用

## 理由

- OAuth設定が簡単
- 運用負荷が低い
```

---

## MVP

```markdown
# GuildWorks MVP

## 実装対象

- Google認証
- プロフィール
- クエスト投稿
- クエスト応募
- 評価

## 実装対象外

- ギルド
- ランキング
- AI機能
```
