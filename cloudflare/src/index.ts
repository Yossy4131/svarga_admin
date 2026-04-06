export interface Env {
  DB: D1Database;
  ADMIN_TOKEN: string;
  IMAGES: R2Bucket;
}

function corsHeaders(origin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Token',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  };
}

function getAllowedOrigin(request: Request): string {
  const origin = request.headers.get('Origin') ?? '*';
  return origin;
}

function json(data: unknown, status = 200, origin = '*'): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders(origin), 'Content-Type': 'application/json' },
  });
}

function err(message: string, status = 400, origin = '*'): Response {
  return json({ error: message }, status, origin);
}

/** 日本時間(JST = UTC+9)の現在時刻を 'YYYY-MM-DDTHH:MM:SS' 形式で返す */
function nowJst(): string {
  return new Date(Date.now() + 9 * 3600 * 1000).toISOString().slice(0, 19);
}

/**
 * 開催日時が過去になった upcoming イベントを自動的に completed に変更する
 */
async function autoCompleteEvents(db: D1Database): Promise<void> {
  await db
    .prepare(`UPDATE events SET status = 'completed' WHERE status = 'upcoming' AND event_date IS NOT NULL AND event_date < ?`)
    .bind(nowJst())
    .run();
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = getAllowedOrigin(request);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    const isAdmin = (): boolean =>
      request.headers.get('X-Admin-Token') === env.ADMIN_TOKEN;

    try {
      // ──────────────────────────────────────────────
      // Public: 次回開催イベント
      // ──────────────────────────────────────────────
      if (method === 'GET' && path === '/api/events/next') {
        await autoCompleteEvents(env.DB);
        const result = await env.DB.prepare(
          `SELECT * FROM events WHERE status = 'upcoming' ORDER BY event_date ASC LIMIT 1`,
        ).first();
        return json(result ?? null, 200, origin);
      }

      // ──────────────────────────────────────────────
      // Public: キャスト一覧
      // ──────────────────────────────────────────────
      if (method === 'GET' && path === '/api/casts') {
        const { results } = await env.DB.prepare(
          `SELECT * FROM casts ORDER BY sort_order ASC, id ASC`,
        ).all();
        return json(results, 200, origin);
      }

      // ──────────────────────────────────────────────
      // Public: R2 画像配信
      // ──────────────────────────────────────────────
      if (method === 'GET' && path.startsWith('/api/images/')) {
        const key = path.slice('/api/images/'.length);
        if (!key) return err('Not found', 404, origin);
        const obj = await env.IMAGES.get(key);
        if (!obj) return err('Not found', 404, origin);
        const headers = new Headers(corsHeaders(origin));
        headers.set('Content-Type', obj.httpMetadata?.contentType ?? 'image/jpeg');
        headers.set('Cache-Control', 'public, max-age=31536000');
        return new Response(obj.body, { headers });
      }

      // ──────────────────────────────────────────────
      // Public: 来店応募
      // ──────────────────────────────────────────────
      if (method === 'POST' && path === '/api/apply') {
        const body = await request.json<{
          vrchat_id?: string;
          x_id?: string;
          event_id?: number | null;
        }>();
        if (!body.vrchat_id?.trim() || !body.x_id?.trim()) {
          return err('VRChat名とX IDは必須です', 400, origin);
        }
        // 直近のupcominigイベントに自動紐付け
        const nextEvent = await env.DB.prepare(
          `SELECT id FROM events WHERE status = 'upcoming' ORDER BY event_date ASC LIMIT 1`,
        ).first<{ id: number }>();

        const effectiveEventId = body.event_id ?? nextEvent?.id ?? null;

        // 重複応募チェック: 同一VRChat ID × 同一開催日
        if (effectiveEventId !== null) {
          const duplicate = await env.DB.prepare(
            `SELECT id FROM applications WHERE vrchat_id = ? AND event_id = ? LIMIT 1`,
          ).bind(body.vrchat_id.trim(), effectiveEventId).first();
          if (duplicate) {
            return err('この開催日にはすでに応募済みです', 409, origin);
          }
        }

        const result = await env.DB.prepare(
          `INSERT INTO applications (vrchat_id, x_id, event_id) VALUES (?, ?, ?) RETURNING id`,
        )
          .bind(
            body.vrchat_id.trim(),
            body.x_id.trim(),
            effectiveEventId,
          )
          .first<{ id: number }>();

        return json({ id: result!.id, message: '応募を受け付けました' }, 201, origin);
      }

      // ──────────────────────────────────────────────
      // Admin routes（トークン検証）
      // ──────────────────────────────────────────────
      if (!isAdmin()) return err('Unauthorized', 401, origin);

      // ── 画像アップロード ──────────────────────────────
      if (method === 'POST' && path === '/api/admin/upload-image') {
        const formData = await request.formData();
        const file = formData.get('file') as File | null;
        if (!file) return err('fileが必要です', 400, origin);
        const ext = (file.type.split('/')[1] ?? 'jpg').replace('jpeg', 'jpg');
        const key = `casts/${crypto.randomUUID()}.${ext}`;
        await env.IMAGES.put(key, file.stream(), {
          httpMetadata: { contentType: file.type },
        });
        const baseUrl = new URL(request.url).origin;
        return json({ url: `${baseUrl}/api/images/${key}` }, 201, origin);
      }

      // ── Events ──────────────────────────────────
      if (path === '/api/admin/events') {
        if (method === 'GET') {
          await autoCompleteEvents(env.DB);
          const { results } = await env.DB.prepare(
            `SELECT * FROM events ORDER BY event_date DESC`,
          ).all();
          return json(results, 200, origin);
        }
        if (method === 'POST') {
          const body = await request.json<{
            event_date?: string;
            recruitment_start?: string;
            recruitment_end?: string;
            recruitment_count?: number;
            venue_capacity?: number;
            status?: string;
          }>();
          const autoTitle = body.event_date
            ? new Date(body.event_date).toLocaleDateString('ja-JP', { timeZone: 'Asia/Tokyo', year: 'numeric', month: 'long', day: 'numeric' }) + ' イベント'
            : 'イベント';
          const result = await env.DB.prepare(
            `INSERT INTO events (title, event_date, recruitment_start, recruitment_end, recruitment_count, venue_capacity, status) VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING *`,
          )
            .bind(autoTitle, body.event_date ?? null, body.recruitment_start ?? null, body.recruitment_end ?? null, body.recruitment_count ?? null, body.venue_capacity ?? null, body.status ?? 'upcoming')
            .first();
          return json(result, 201, origin);
        }
      }

      const evMatch = path.match(/^\/api\/admin\/events\/(\d+)$/);
      if (evMatch) {
        const id = parseInt(evMatch[1]);
        if (method === 'PUT') {
          const body = await request.json<{
            event_date?: string;
            recruitment_start?: string;
            recruitment_end?: string;
            recruitment_count?: number;
            venue_capacity?: number;
            status: string;
          }>();
          const autoTitle = body.event_date
            ? new Date(body.event_date).toLocaleDateString('ja-JP', { timeZone: 'Asia/Tokyo', year: 'numeric', month: 'long', day: 'numeric' }) + ' イベント'
            : 'イベント';
          const result = await env.DB.prepare(
            `UPDATE events SET title = ?, event_date = ?, recruitment_start = ?, recruitment_end = ?, recruitment_count = ?, venue_capacity = ?, status = ? WHERE id = ? RETURNING *`,
          )
            .bind(autoTitle, body.event_date ?? null, body.recruitment_start ?? null, body.recruitment_end ?? null, body.recruitment_count ?? null, body.venue_capacity ?? null, body.status, id)
            .first();
          if (!result) return err('Not found', 404, origin);
          return json(result, 200, origin);
        }
        if (method === 'DELETE') {
          await env.DB.prepare(`DELETE FROM events WHERE id = ?`).bind(id).run();
          return json({ success: true }, 200, origin);
        }
      }

      // ── Applications ─────────────────────────────
      if (path === '/api/admin/applications') {
        if (method === 'GET') {
          const eventId = url.searchParams.get('event_id');
          const query = eventId
            ? env.DB.prepare(
                `SELECT * FROM applications WHERE event_id = ? ORDER BY created_at DESC`,
              ).bind(eventId)
            : env.DB.prepare(
                `SELECT * FROM applications ORDER BY created_at DESC`,
              );
          const { results } = await query.all();
          return json(results, 200, origin);
        }
      }

      const appMatch = path.match(/^\/api\/admin\/applications\/(\d+)$/);
      if (appMatch) {
        const id = parseInt(appMatch[1]);
        if (method === 'PATCH') {
          const body = await request.json<{ status: string }>();
          const result = await env.DB.prepare(
            `UPDATE applications SET status = ? WHERE id = ? RETURNING *`,
          )
            .bind(body.status, id)
            .first();
          if (!result) return err('Not found', 404, origin);
          return json(result, 200, origin);
        }
        if (method === 'DELETE') {
          await env.DB.prepare(`DELETE FROM applications WHERE id = ?`).bind(id).run();
          return json({ success: true }, 200, origin);
        }
      }

      // ── Casts ────────────────────────────────────
      if (path === '/api/admin/casts') {
        if (method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT * FROM casts ORDER BY sort_order ASC, id ASC`,
          ).all();
          return json(results, 200, origin);
        }
        if (method === 'POST') {
          const body = await request.json<{
            name?: string;
            role?: string;
            message?: string;
            avatar_url?: string;
            avatar_full_url?: string;
          }>();
          if (!body.name?.trim()) return err('nameは必須です', 400, origin);
          // 現在の最大 sort_order を取得して末尾に追加
          const maxRow = await env.DB.prepare(
            `SELECT COALESCE(MAX(sort_order), -1) AS max_order FROM casts`,
          ).first<{ max_order: number }>();
          const nextOrder = (maxRow?.max_order ?? -1) + 1;
          const result = await env.DB.prepare(
            `INSERT INTO casts (name, role, message, avatar_url, avatar_full_url, sort_order) VALUES (?, ?, ?, ?, ?, ?) RETURNING *`,
          )
            .bind(
              body.name.trim(),
              body.role ?? 'キャスト',
              body.message ?? '',
              body.avatar_url ?? null,
              body.avatar_full_url ?? null,
              nextOrder,
            )
            .first();
          return json(result, 201, origin);
        }
      }

      // キャスト並び替え
      if (method === 'PUT' && path === '/api/admin/casts/reorder') {
        if (!isAdmin()) return err('Unauthorized', 401, origin);
        const body = await request.json<{ ids?: number[] }>();
        if (!Array.isArray(body.ids)) return err('idsは必須です', 400, origin);
        const stmts = body.ids.map((id, index) =>
          env.DB.prepare(`UPDATE casts SET sort_order = ? WHERE id = ?`).bind(index, id),
        );
        await env.DB.batch(stmts);
        return json({ success: true }, 200, origin);
      }

      const castMatch = path.match(/^\/api\/admin\/casts\/(\d+)$/);
      if (castMatch) {
        const id = parseInt(castMatch[1]);
        if (method === 'PUT') {
          const body = await request.json<{
            name: string;
            role: string;
            message: string;
            avatar_url?: string;
            avatar_full_url?: string;
          }>();
          if (!body.name?.trim()) return err('nameは必須です', 400, origin);
          const result = await env.DB.prepare(
            `UPDATE casts SET name = ?, role = ?, message = ?, avatar_url = ?, avatar_full_url = ?, updated_at = datetime('now', '+9 hours') WHERE id = ? RETURNING *`,
          )
            .bind(
              body.name.trim(),
              body.role,
              body.message,
              body.avatar_url ?? null,
              body.avatar_full_url ?? null,
              id,
            )
            .first();
          if (!result) return err('Not found', 404, origin);
          return json(result, 200, origin);
        }
        if (method === 'DELETE') {
          await env.DB.prepare(`DELETE FROM casts WHERE id = ?`).bind(id).run();
          return json({ success: true }, 200, origin);
        }
      }

      return err('Not found', 404, origin);
    } catch (e: unknown) {
      const message = e instanceof Error ? e.message : 'Internal server error';
      return err(message, 500, origin);
    }
  },
};
