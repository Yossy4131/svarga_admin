-- Svarga Lethal — D1 スキーマ
-- 適用: wrangler d1 execute svarga-db --file=./schema.sql

CREATE TABLE IF NOT EXISTS events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  title       TEXT    NOT NULL,
  event_date  TEXT,                                      -- ISO 8601 (例: 2026-05-03T20:00:00)
  status      TEXT    NOT NULL DEFAULT 'upcoming',       -- upcoming / completed / cancelled
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS applications (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  vrchat_id   TEXT    NOT NULL,
  x_id        TEXT    NOT NULL,
  event_id    INTEGER REFERENCES events(id) ON DELETE SET NULL,
  status      TEXT    NOT NULL DEFAULT 'pending',        -- pending / approved / rejected
  created_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- 同一VRChat ID × 同一開催日への重複応募をDB層で防止
-- 注意: event_id = NULLのRowはSQLiteのNULLネィークプリシットのため制約対象外だが、
--       Worker側でも同様のチェックを実施済み
CREATE UNIQUE INDEX IF NOT EXISTS uq_applications_vrchat_event
  ON applications (vrchat_id, event_id);

CREATE TABLE IF NOT EXISTS casts (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        TEXT    NOT NULL,
  role        TEXT    NOT NULL DEFAULT 'キャスト',
  message     TEXT    NOT NULL DEFAULT '',
  avatar_url  TEXT,
  avatar_full_url TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);
