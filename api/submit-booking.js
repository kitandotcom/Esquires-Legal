const buckets = new Map();
const WINDOW_MS = 10 * 60 * 1000;
const MAX_REQUESTS = 5;
const MAX_BODY_BYTES = 12 * 1024;

function json(res, status, body) {
  res.status(status).setHeader('Cache-Control', 'no-store');
  return res.json(body);
}

function clientIp(req) {
  return String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || 'unknown').split(',')[0].trim();
}

function clean(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

export default async function handler(req, res) {
  res.setHeader('Allow', 'POST');
  if (req.method !== 'POST') return json(res, 405, { error: 'Method not allowed' });

  const origin = req.headers.origin;
  const host = req.headers.host;
  if (origin && host) {
    try { if (new URL(origin).host !== host) return json(res, 403, { error: 'Forbidden' }); }
    catch { return json(res, 403, { error: 'Forbidden' }); }
  }
  if (Number(req.headers['content-length'] || 0) > MAX_BODY_BYTES) return json(res, 413, { error: 'Request too large' });

  const now = Date.now();
  const ip = clientIp(req);
  const bucket = buckets.get(ip) || { count: 0, reset: now + WINDOW_MS };
  if (now > bucket.reset) { bucket.count = 0; bucket.reset = now + WINDOW_MS; }
  bucket.count += 1;
  buckets.set(ip, bucket);
  if (bucket.count > MAX_REQUESTS) {
    res.setHeader('Retry-After', String(Math.ceil((bucket.reset - now) / 1000)));
    return json(res, 429, { error: 'Too many requests' });
  }

  const body = req.body || {};
  if (clean(body.website, 100)) return json(res, 400, { error: 'Invalid request' });
  const record = {
    name: clean(body.name, 120),
    phone: clean(body.phone, 40) || null,
    email: clean(body.email, 254) || null,
    organisation: clean(body.organisation, 160) || null,
    area: clean(body.area, 160) || null,
    note: clean(body.note, 4000) || null,
  };
  if (!record.name) return json(res, 400, { error: 'Name is required' });
  if (record.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(record.email)) return json(res, 400, { error: 'Invalid email' });

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) return json(res, 503, { error: 'Service unavailable' });

  try {
    const upstream = await fetch(`${supabaseUrl}/rest/v1/bookings`, {
      method: 'POST',
      headers: {
        apikey: serviceRoleKey,
        Authorization: `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        Prefer: 'return=minimal',
      },
      body: JSON.stringify(record),
    });
    if (!upstream.ok) return json(res, 502, { error: 'Could not save request' });
    return json(res, 201, { ok: true });
  } catch {
    return json(res, 502, { error: 'Could not save request' });
  }
}
