export interface Env {
  DB: D1Database;
  ADMIN_TOKEN: string;
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
          `SELECT * FROM casts ORDER BY id ASC`,
        ).all();
        return json(results, 200, origin);
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
          return err('VRChat IDとX IDは必須です', 400, origin);
        }
        // 直近のupcomingイベントに自動紐付け
        const nextEvent = await env.DB.prepare(
          `SELECT id FROM events WHERE status = 'upcoming' ORDER BY event_date ASC LIMIT 1`,
        ).first<{ id: number }>();

        const result = await env.DB.prepare(
          `INSERT INTO applications (vrchat_id, x_id, event_id) VALUES (?, ?, ?) RETURNING id`,
        )
          .bind(
            body.vrchat_id.trim(),
            body.x_id.trim(),
            body.event_id ?? nextEvent?.id ?? null,
          )
          .first<{ id: number }>();

        return json({ id: result!.id, message: '応募を受け付けました' }, 201, origin);
      }

      // ──────────────────────────────────────────────
      // Admin routes（トークン検証）
      // ──────────────────────────────────────────────
      if (!isAdmin()) return err('Unauthorized', 401, origin);

      // ── Events ──────────────────────────────────
      if (path === '/api/admin/events') {
        if (method === 'GET') {
          const { results } = await env.DB.prepare(
            `SELECT * FROM events ORDER BY event_date DESC`,
          ).all();
          return json(results, 200, origin);
        }
        if (method === 'POST') {
          const body = await request.json<{
            title?: string;
            event_date?: string;
            status?: string;
          }>();
          if (!body.title?.trim()) return err('titleは必須です', 400, origin);
          const result = await env.DB.prepare(
            `INSERT INTO events (title, event_date, status) VALUES (?, ?, ?) RETURNING *`,
          )
            .bind(body.title.trim(), body.event_date ?? null, body.status ?? 'upcoming')
            .first();
          return json(result, 201, origin);
        }
      }

      const evMatch = path.match(/^\/api\/admin\/events\/(\d+)$/);
      if (evMatch) {
        const id = parseInt(evMatch[1]);
        if (method === 'PUT') {
          const body = await request.json<{
            title: string;
            event_date?: string;
            status: string;
          }>();
          if (!body.title?.trim()) return err('titleは必須です', 400, origin);
          const result = await env.DB.prepare(
            `UPDATE events SET title = ?, event_date = ?, status = ? WHERE id = ? RETURNING *`,
          )
            .bind(body.title.trim(), body.event_date ?? null, body.status, id)
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
            `SELECT * FROM casts ORDER BY id ASC`,
          ).all();
          return json(results, 200, origin);
        }
        if (method === 'POST') {
          const body = await request.json<{
            name?: string;
            role?: string;
            message?: string;
            avatar_url?: string;
          }>();
          if (!body.name?.trim()) return err('nameは必須です', 400, origin);
          const result = await env.DB.prepare(
            `INSERT INTO casts (name, role, message, avatar_url) VALUES (?, ?, ?, ?) RETURNING *`,
          )
            .bind(
              body.name.trim(),
              body.role ?? 'キャスト',
              body.message ?? '',
              body.avatar_url ?? null,
            )
            .first();
          return json(result, 201, origin);
        }
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
          }>();
          if (!body.name?.trim()) return err('nameは必須です', 400, origin);
          const result = await env.DB.prepare(
            `UPDATE casts SET name = ?, role = ?, message = ?, avatar_url = ?, updated_at = datetime('now') WHERE id = ? RETURNING *`,
          )
            .bind(
              body.name.trim(),
              body.role,
              body.message,
              body.avatar_url ?? null,
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
