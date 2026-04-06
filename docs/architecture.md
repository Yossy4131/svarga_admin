# アーキテクチャ設計書 — Svarga Lethal

## 1. システム全体構成

```
┌─────────────────────────────────────────────────────────────────┐
│                         クライアント                              │
│                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────────────┐  │
│  │   svarga_lethal      │     │       svarga_admin           │  │
│  │   (Flutter Web)      │     │  (Flutter Web / Windows)     │  │
│  │                      │     │                              │  │
│  │  - 公開案内サイト     │     │  - イベント管理              │  │
│  │  - 来店申込フォーム   │     │  - キャスト管理              │  │
│  │  - キャスト紹介       │     │  - 申込管理 / 抽選           │  │
│  └──────────┬───────────┘     └───────────────┬──────────────┘  │
│             │ HTTPS / REST                     │ HTTPS / REST   │
│             │ (公開 API)                        │ (Admin API)    │
└─────────────┼──────────────────────────────────┼────────────────┘
              │                                  │
              ▼                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Cloudflare Workers (Edge)                     │
│                                                                 │
│   エンドポイント: <your-worker-subdomain>.workers.dev            │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │  src/index.ts                                            │  │
│   │                                                          │  │
│   │  - ルーティング (path / method マッチ)                   │  │
│   │  - CORS ヘッダー付与                                     │  │
│   │  - X-Admin-Token 認証（管理ルート）                      │  │
│   │  - nowJst() : JST 現在時刻                               │  │
│   │  - autoCompleteEvents() : イベント自動終了               │  │
│   └──────────────────────────────────────────────────────────┘  │
│             │                         │                         │
│             ▼                         ▼                         │
│   ┌─────────────────┐     ┌─────────────────────────────────┐   │
│   │  D1 Database    │     │  R2 Bucket (svarga-images)      │   │
│   │  (svarga-db)    │     │                                 │   │
│   │                 │     │  casts/{uuid}.jpg  など          │   │
│   │  - events       │     │  Worker 経由で配信               │   │
│   │  - applications │     │  Cache-Control: 1年              │   │
│   │  - casts        │     └─────────────────────────────────┘   │
│   └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Cloudflare Pages (svarga-admin)                    │
│              Flutter Web ビルド成果物をホスト                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. フロントエンド構成

### 2.1 svarga_lethal（公開サイト）

```
lib/
├── main.dart                  # アプリエントリポイント・テーマ設定
├── services/
│   └── api_service.dart       # API 呼び出し・TTL キャッシュ・プリフェッチ
├── widgets/
│   └── brand_logo.dart        # ブランドロゴ Widget
└── pages/
    ├── splash_page.dart       # スプラッシュ（アニメーション + プリフェッチ起動）
    ├── top_page.dart          # TOP ランディングページ
    ├── cast_page.dart         # キャスト一覧
    ├── cast_detail_page.dart  # キャスト詳細
    └── apply_page.dart        # 来店申込フォーム
```

**キャッシュ戦略（api_service.dart）**

```
リクエスト
  │
  ├─ _cachedXxx != null && 期限内? ──→ キャッシュから返す
  │
  ├─ _xxxFuture 進行中? ──────────→ 同じ Future を返す（二重リクエスト防止）
  │
  └─ それ以外 ───────────────────→ HTTP リクエスト → キャッシュ保存（TTL 5分）
```

### 2.2 svarga_admin（管理アプリ）

```
lib/
├── main.dart                  # アプリエントリポイント・テーマ設定
├── api/
│   └── api_client.dart        # HTTP クライアント（X-Admin-Token 付与）
├── models/
│   ├── cast_model.dart        # Cast データモデル
│   └── event_model.dart       # Event データモデル
└── pages/
    ├── login_page.dart        # ログイン画面
    ├── admin_shell.dart       # 認証後シェル（NavigationRail）
    ├── events_page.dart       # イベント管理
    ├── casts_page.dart        # キャスト管理
    └── applications_page.dart # 申込管理
```

---

## 3. バックエンド構成（Cloudflare Workers）

```
cloudflare/
├── src/
│   └── index.ts              # Worker 本体（全エンドポイント）
├── schema.sql                # D1 テーブル定義
├── wrangler.toml             # バインディング設定（D1 / R2 / Secrets）
├── package.json              # npm 依存
└── tsconfig.json             # TypeScript 設定
```

### バインディング

| 名前 | 種別 | 用途 |
|------|------|------|
| `DB` | D1 Database | `svarga-db` — イベント・申込・キャスト |
| `IMAGES` | R2 Bucket | `svarga-images` — キャストアバター画像 |
| `ADMIN_TOKEN` | Secret | 管理 API 認証トークン |

---

## 4. データフロー

### 来店申込フロー

```
ユーザー → apply_page.dart
  └→ POST /api/apply { vrchat_id, x_id }
       └→ Worker: 直近 upcoming イベントに自動紐付け
            └→ D1: applications テーブルに INSERT
                 └→ 管理者: applications_page.dart で確認・承認/却下
```

### キャスト画像アップロードフロー

```
管理者 → casts_page.dart (image_picker で選択)
  └→ POST /api/admin/upload-image (multipart/form-data)
       └→ Worker: UUID ファイル名で R2 に PUT
            └→ /api/images/{key} URL を返す
                 └→ PUT /api/admin/casts/{id} で avatar_url を保存
```

### イベント自動終了フロー

```
GET /api/events/next または GET /api/admin/events アクセス時
  └→ autoCompleteEvents() を実行
       └→ event_date < nowJst() の upcoming イベントを completed に更新
```

---

## 5. 認証・認可

```
リクエスト
  │
  ├─ パス が /api/admin/* ではない? ──→ 認証不要（パブリック）
  │
  └─ isAdmin() チェック
       └─ X-Admin-Token ヘッダー == ADMIN_TOKEN (Secret)?
            ├─ OK ──→ 処理続行
            └─ NG ──→ 401 Unauthorized
```

- `ADMIN_TOKEN` は Cloudflare Dashboard または `wrangler secret put` でのみ設定可能
- ソースコードおよび Git リポジトリには含めない

---

## 6. CI / CD パイプライン

```
git push origin main
  │
  └─ GitHub Actions: deploy.yml
       │
       ├─ Job 1: deploy-worker
       │    ├─ npm install (cloudflare/)
       │    ├─ wrangler deploy (Worker)
       │    └─ wrangler secret put ADMIN_TOKEN
       │
       └─ Job 2: deploy-pages (needs: deploy-worker)
            ├─ flutter pub get
            ├─ flutter build web --release
            └─ wrangler pages deploy build/web --project-name=svarga-admin
```

### 必要な GitHub Secrets

| 名前 | 説明 |
|------|------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API トークン（Workers + Pages + R2 権限） |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare アカウント ID |
| `ADMIN_TOKEN` | 管理 API 認証トークン（`X-Admin-Token` ヘッダーと照合） |

---

## 7. 技術スタック一覧

| レイヤー | 技術 | バージョン |
|---------|------|-----------|
| フロントエンド | Flutter | 3.41.6 |
| フォント | Google Fonts — Shippori Mincho | ^6.2.1 |
| HTTP クライアント | `package:http` | ^1.2.2 |
| 画像選択 | `image_picker` | ^1.1.2 |
| バックエンドランタイム | Cloudflare Workers (TypeScript) | - |
| データベース | Cloudflare D1 (SQLite 互換) | - |
| 画像ストレージ | Cloudflare R2 | - |
| ホスティング | Cloudflare Pages | - |
| CI / CD | GitHub Actions | - |
