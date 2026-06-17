# Next.js環境構築

■インストール系

    Node.js（推奨：18以上 or 20 LTS）

■DB環境

    Supabase


■DB環境  

    Supabase  
    ├ 認証系のサービス提供してくれてる  
    └ レベルの高い認証サービス  

■ディレクトリでやること

    ```Bash
    npx create-next-app@latest
    ```

■初期設定

    - TypeScriptを使う？ → Yes（基本YES推奨）
    - ESLint使う？ → Yes
    - Tailwind使う？ → 好み（初心者はYesおすすめ）
    - App Router使う？ → Yes（重要）
    - srcディレクトリ使う？ → Yes（整理しやすい）
    - import alias使う？ → Yes（@/が使える）

■開発サーバー起動

    ```Bash
    npm run dev
    ```

■ブラウザで確認

    http://localhost:3000

■ポートが埋まってる場合

    ```Bash
    npm run dev -- -p 3001
    ```