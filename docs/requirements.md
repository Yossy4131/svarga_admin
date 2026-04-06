# 要件定義書 — Svarga Lethal 管理システム

## 1. プロジェクト概要

| 項目 | 内容 |
|------|------|
| サービス名 | Svarga Lethal |
| サービス種別 | VRChat 内ホストクラブ（リーサルフリートアバターオンリー） |
| システム構成 | 公開サイト（svarga_lethal） ＋ 管理アプリ（svarga_admin） |
| 管理者 | 店舗オーナー・スタッフ（少人数想定） |

---

## 2. 利用者

| 区分 | 説明 |
|------|------|
| 一般ユーザー | 公開サイトを閲覧し、来店申込を行う VRChat プレイヤー |
| 管理者 | イベント・キャスト・申込を管理する店舗スタッフ |

---

## 3. 機能要件

### 3.1 公開サイト（svarga_lethal）

| ID | 機能 | 優先 |
|----|------|------|
| F-01 | TOP ページにブランドロゴ・キャッチコピー・店内スライドショーを表示する | 必須 |
| F-02 | 次回開催イベントの日時をリアルタイムで取得・表示する | 必須 |
| F-03 | キャスト一覧を `sort_order` 順で表示する | 必須 |
| F-04 | キャスト詳細（アバター画像・役職・自己紹介）を表示する | 必須 |
| F-05 | 来店申込フォーム（VRChat ID / X ID）から申込を送信できる | 必須 |
| F-06 | スプラッシュ画面でアニメーションを表示しつつ API をプリフェッチする | 推奨 |
| F-07 | サイドドロワーにナビゲーションメニューを設置する | 必須 |

### 3.2 管理アプリ（svarga_admin）

| ID | 機能 | 優先 |
|----|------|------|
| A-01 | 管理者トークンによるログイン認証 | 必須 |
| A-02 | イベントの新規作成・編集・削除 | 必須 |
| A-03 | イベント開催日時が過去になったとき自動で `completed` に変更する（JST基準） | 必須 |
| A-04 | キャストの追加・編集・削除 | 必須 |
| A-05 | キャストアバター画像のアップロード（Cloudflare R2） | 必須 |
| A-06 | キャストの役職をプルダウン＋Chip UIで複数選択できる | 必須 |
| A-07 | キャストの表示順をドラッグ＆ドロップで並び替えできる | 必須 |
| A-08 | 来店申込一覧の表示・イベント／ステータスフィルタリング | 必須 |
| A-09 | 申込の承認（approved）・却下（rejected） | 必須 |
| A-10 | 抽選機能：イベントと当選人数を指定しランダム抽選→一括承認 | 推奨 |

---

## 4. 非機能要件

| 分類 | 要件 |
|------|------|
| パフォーマンス | 公開サイトの初回データ取得をスプラッシュ中に完了させる（体感ゼロ待ち） |
| キャッシュ | API レスポンスを 5分 TTL でクライアントキャッシュする |
| セキュリティ | 管理エンドポイントはすべて `X-Admin-Token` ヘッダーで保護する |
| CORS | 全オリジン許可（Cloudflare Workers レイヤーで対応） |
| 可用性 | Cloudflare エッジネットワーク上で動作させ、高可用性を担保する |
| コスト | Cloudflare Workers / D1 / R2 の無料枠に収まる規模で運用する |
| 対応プラットフォーム | 公開サイト: Web（モバイル・PC）/ 管理アプリ: Web・Windows |

---

## 5. データ要件

### イベント（events）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | INTEGER | 主キー（自動採番） |
| title | TEXT | タイトル（日時から自動生成） |
| event_date | TEXT | 開催日時（ISO 8601） |
| recruitment_start | TEXT | 募集開始日時 |
| recruitment_end | TEXT | 募集終了日時 |
| recruitment_count | INTEGER | 募集人数 |
| venue_capacity | INTEGER | 会場定員 |
| status | TEXT | upcoming / completed / cancelled |
| created_at | TEXT | 作成日時（JST） |

### キャスト（casts）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | INTEGER | 主キー |
| name | TEXT | キャスト名 |
| role | TEXT | 役職（カンマ区切り複数可） |
| message | TEXT | 自己紹介メッセージ |
| avatar_url | TEXT | サムネイル画像 URL（R2） |
| avatar_full_url | TEXT | フル画像 URL（R2） |
| sort_order | INTEGER | 表示順 |
| updated_at | TEXT | 更新日時（JST） |

### 申込（applications）

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | INTEGER | 主キー |
| vrchat_id | TEXT | VRChat ユーザー ID |
| x_id | TEXT | X（旧 Twitter）ID |
| event_id | INTEGER | 紐付けイベント ID（外部キー） |
| status | TEXT | pending / approved / rejected |
| created_at | TEXT | 申込日時（JST） |

---

## 6. 制約・前提

- 申込は公開サイトのフォームのみ受付（API 直叩き不可とはしないが、UI は提供しない）
- 管理者トークンは環境変数（Cloudflare Secret）で管理し、ソースコードに含めない
- 画像は Cloudflare R2 に保存し、Worker 経由で配信（直接 R2 URL は公開しない）
