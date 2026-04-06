# API 仕様書 — Svarga Lethal Worker

**Base URL**: `https://<your-worker-subdomain>.workers.dev`

---

## 認証

管理者向けエンドポイント（`/api/admin/*`）は以下のヘッダーが必要です。

```
X-Admin-Token: <ADMIN_TOKEN>
```

トークンが一致しない場合は `401 Unauthorized` を返します。

---

## 共通レスポンス形式

### 成功

```json
// 単一オブジェクト
{ "id": 1, "title": "...", ... }

// 一覧
[ { "id": 1, ... }, { "id": 2, ... } ]
```

### エラー

```json
{ "error": "エラーメッセージ" }
```

| ステータス | 意味 |
|-----------|------|
| 400 | リクエスト不正（必須パラメータ不足など） |
| 401 | 認証失敗（X-Admin-Token 不一致） |
| 404 | リソースが見つからない |
| 500 | サーバー内部エラー |

---

## パブリック API

### GET /api/events/next

次回開催イベント（`status = 'upcoming'` の最古のもの）を返します。  
呼び出し時に `autoCompleteEvents()` が実行され、開催済みイベントは自動的に `completed` に更新されます。

**レスポンス**

```json
{
  "id": 1,
  "title": "2026年5月3日 イベント",
  "event_date": "2026-05-03T20:00:00",
  "recruitment_start": "2026-04-20T12:00:00",
  "recruitment_end": "2026-05-01T23:59:59",
  "recruitment_count": 30,
  "venue_capacity": 50,
  "status": "upcoming",
  "created_at": "2026-04-01T10:00:00"
}
```

イベントがない場合は `null` を返します。

---

### GET /api/casts

キャスト一覧を `sort_order ASC, id ASC` 順で返します。

**レスポンス**

```json
[
  {
    "id": 1,
    "name": "キャスト名",
    "role": "キャスト,バーテンダー",
    "message": "自己紹介メッセージ",
    "avatar_url": "https://.../api/images/casts/uuid.jpg",
    "avatar_full_url": "https://.../api/images/casts/uuid_full.jpg",
    "sort_order": 0,
    "updated_at": "2026-04-06T20:00:00"
  }
]
```

---

### GET /api/images/{key}

R2 バケット内の画像を配信します。

| パラメータ | 説明 |
|-----------|------|
| key | R2 オブジェクトキー（例: `casts/uuid.jpg`） |

**レスポンス**: 画像バイナリ（`Content-Type` は R2 のメタデータ準拠）  
`Cache-Control: public, max-age=31536000`（1年）

---

### POST /api/apply

来店申込を送信します。直近の `upcoming` イベントに自動紐付けされます。

**リクエストボディ**

```json
{
  "vrchat_id": "ExampleUser",
  "x_id": "@example",
  "event_id": 1
}
```

| フィールド | 必須 | 説明 |
|-----------|------|------|
| vrchat_id | ✓ | VRChat ユーザー名 |
| x_id | ✓ | X（旧 Twitter）ID |
| event_id | - | 紐付けるイベント ID（省略時は直近 upcoming に自動紐付け） |

**レスポンス** `201 Created`

```json
{ "id": 42, "message": "応募を受け付けました" }
```

---

## 管理 API

### POST /api/admin/upload-image

アバター画像を R2 にアップロードします。

**リクエスト**: `multipart/form-data`

| フィールド | 必須 | 説明 |
|-----------|------|------|
| file | ✓ | 画像ファイル（JPEG / PNG 等） |

**レスポンス** `201 Created`

```json
{ "url": "https://.../api/images/casts/uuid.jpg" }
```

---

### GET /api/admin/events

全イベント一覧を返します（`event_date DESC` 順）。呼び出し時に `autoCompleteEvents()` が実行されます。

**レスポンス**: イベントオブジェクトの配列

---

### POST /api/admin/events

イベントを新規作成します。タイトルは `event_date` から自動生成されます。

**リクエストボディ**

```json
{
  "event_date": "2026-05-03T20:00:00",
  "recruitment_start": "2026-04-20T12:00:00",
  "recruitment_end": "2026-05-01T23:59:59",
  "recruitment_count": 30,
  "venue_capacity": 50,
  "status": "upcoming"
}
```

**レスポンス** `201 Created`: 作成されたイベントオブジェクト

---

### PUT /api/admin/events/{id}

イベントを更新します。

**リクエストボディ**: POST と同じ形式（`status` 必須）

**レスポンス** `200 OK`: 更新後のイベントオブジェクト

---

### DELETE /api/admin/events/{id}

イベントを削除します。

**レスポンス** `200 OK`

```json
{ "success": true }
```

---

### GET /api/admin/applications

申込一覧を返します（`created_at DESC` 順）。

**クエリパラメータ**

| パラメータ | 説明 |
|-----------|------|
| event_id | 指定した場合、そのイベントの申込のみ返す |

**レスポンス**: 申込オブジェクトの配列

```json
[
  {
    "id": 1,
    "vrchat_id": "ExampleUser",
    "x_id": "@example",
    "event_id": 1,
    "status": "pending",
    "created_at": "2026-04-07T15:00:00"
  }
]
```

---

### PATCH /api/admin/applications/{id}

申込ステータスを更新します。

**リクエストボディ**

```json
{ "status": "approved" }
```

| status 値 | 説明 |
|-----------|------|
| pending | 審査待ち（デフォルト） |
| approved | 承認 |
| rejected | 却下 |

**レスポンス** `200 OK`: 更新後の申込オブジェクト

---

### DELETE /api/admin/applications/{id}

申込を削除します。

**レスポンス** `200 OK` `{ "success": true }`

---

### GET /api/admin/casts

キャスト一覧を返します（`sort_order ASC, id ASC` 順）。

**レスポンス**: キャストオブジェクトの配列

---

### POST /api/admin/casts

キャストを新規追加します。`sort_order` は既存の最大値 +1 が自動設定されます。

**リクエストボディ**

```json
{
  "name": "キャスト名",
  "role": "キャスト,バーテンダー",
  "message": "よろしくお願いします",
  "avatar_url": "https://.../api/images/casts/uuid.jpg",
  "avatar_full_url": "https://.../api/images/casts/uuid_full.jpg"
}
```

| フィールド | 必須 | 説明 |
|-----------|------|------|
| name | ✓ | キャスト名 |
| role | - | 役職（カンマ区切り、デフォルト: `"キャスト"`） |
| message | - | 自己紹介 |
| avatar_url | - | サムネイル URL |
| avatar_full_url | - | フル画像 URL |

**レスポンス** `201 Created`: 作成されたキャストオブジェクト

---

### PUT /api/admin/casts/reorder

キャストの表示順を一括更新します。

**リクエストボディ**

```json
{ "ids": [3, 1, 4, 2] }
```

`ids` の配列インデックスが `sort_order` の値になります（0始まり）。

**レスポンス** `200 OK` `{ "success": true }`

---

### PUT /api/admin/casts/{id}

キャスト情報を更新します。`updated_at` は JST で自動更新されます。

**リクエストボディ**: POST と同じ形式（`name` 必須）

**レスポンス** `200 OK`: 更新後のキャストオブジェクト

---

### DELETE /api/admin/casts/{id}

キャストを削除します。

**レスポンス** `200 OK` `{ "success": true }`
