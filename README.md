# Svarga Lethal — 管理アプリ

Svarga Lethal の管理者向けアプリです。  
Flutter (Web / Desktop) ＋ Cloudflare Workers / D1 / R2 で構成されています。

## リポジトリ構成

```
svarga_admin/
├── lib/                  # Flutter アプリ本体
│   ├── api/              # API クライアント (api_client.dart)
│   ├── models/           # データモデル (cast_model.dart 等)
│   └── pages/            # 各管理画面
│       ├── login_page.dart
│       ├── admin_shell.dart
│       ├── events_page.dart
│       ├── casts_page.dart
│       └── applications_page.dart
└── cloudflare/           # Cloudflare Worker (TypeScript)
    ├── src/index.ts      # API エンドポイント実装
    ├── schema.sql        # D1 テーブル定義
    └── wrangler.toml     # Worker 設定
```

## 機能概要

| 画面 | 機能 |
|------|------|
| ログイン | ADMIN_TOKEN 認証 |
| イベント管理 | 新規作成・編集・削除／JST 基準の自動ステータス更新 |
| キャスト管理 | 追加・編集・削除・アバター画像アップロード・ドラッグ並び替え・役職 Chip 選択 |
| 申込管理 | 一覧表示・承認/却下・イベント/ステータスフィルター・抽選機能 |

## 技術スタック

- **Flutter** (Web / Windows / macOS)
- **フォント**: Google Fonts — Shippori Mincho
- **バックエンド**: Cloudflare Workers (TypeScript)
- **DB**: Cloudflare D1 (SQLite 互換) — `svarga-db`
- **画像ストレージ**: Cloudflare R2 — `svarga-images`
- **Worker URL**: `https://<your-worker-subdomain>.workers.dev`（`lib/config/env.dart` に設定）

## D1 テーブル構成

| テーブル | 主なカラム |
|---------|-----------|
| `events` | id, title, event_date, status (upcoming/completed/cancelled) |
| `applications` | id, vrchat_id, x_id, event_id, status (pending/approved/rejected) |
| `casts` | id, name, role (カンマ区切り複数), message, avatar_url, sort_order |

## ローカル起動

```bash
flutter pub get
flutter run -d chrome   # または -d windows
```

## Cloudflare Worker — ローカル開発

```bash
cd cloudflare
npm install
npx wrangler dev        # ローカルサーバー起動
```

## Cloudflare 初回セットアップ

```bash
# D1 データベース作成
npx wrangler d1 create svarga-db

# スキーマ適用
npx wrangler d1 execute svarga-db --file=./schema.sql

# R2 バケット作成
npx wrangler r2 bucket create svarga-images

# 管理トークン設定
echo "your-token" | npx wrangler secret put ADMIN_TOKEN

# Worker デプロイ
npx wrangler deploy
```

> `wrangler.toml` の `database_id` は `wrangler d1 create` 実行後に出力された値に更新してください。

## CI / CD (GitHub Actions)

`main` ブランチへの push で自動デプロイが走ります。

```
push → deploy-worker (Cloudflare Worker) → deploy-pages (Flutter Web → Cloudflare Pages)
```

### 必要な GitHub Secrets

| シークレット名 | 説明 |
|--------------|------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API トークン |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare アカウント ID |
| `ADMIN_TOKEN` | 管理アプリ認証トークン |

## 主な依存パッケージ

```yaml
http: ^1.2.2
http_parser: ^4.0.2
google_fonts: ^6.2.1
image_picker: ^1.1.2
```
