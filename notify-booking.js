// ---------------------------------------------------------------------------
// /api/notify-booking
// ---------------------------------------------------------------------------
// Called by a Supabase Database Webhook whenever a row is inserted into
// public.bookings. Sends an email notification via Resend.
//
// Setup required (see notification-setup.md for full steps):
//   1. Add a RESEND_API_KEY environment variable in Vercel project settings.
//   2. Add a NOTIFY_EMAIL environment variable — the address that should
//      receive booking alerts (e.g. your own email).
//   3. In Supabase: Database -> Webhooks -> Create a new webhook
//        Table: bookings
//        Events: Insert
//        Type: HTTP Request
//        URL: https://<your-vercel-domain>/api/notify-booking
//        HTTP Headers: none required
//   4. Redeploy on Vercel so the new env vars take effect.
// ---------------------------------------------------------------------------

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const RESEND_API_KEY = process.env.RESEND_API_KEY;
  const NOTIFY_EMAIL = process.env.NOTIFY_EMAIL;

  if (!RESEND_API_KEY || !NOTIFY_EMAIL) {
    console.error('Missing RESEND_API_KEY or NOTIFY_EMAIL env var');
    return res.status(500).json({ error: 'Server not configured' });
  }

  // Supabase Database Webhooks send { type, table, record, old_record, schema }
  const body = req.body || {};
  const record = body.record || {};

  const name = record.name || '(no name given)';
  const phone = record.phone || '—';
  const email = record.email || '—';
  const organisation = record.organisation || '—';
  const area = record.area || '—';
  const note = record.note || '—';
  const createdAt = record.created_at || new Date().toISOString();

  const html = `
    <h2>New Consultation Request — Esquires' Legal</h2>
    <table cellpadding="6" style="border-collapse:collapse;">
      <tr><td><strong>Name</strong></td><td>${escapeHtml(name)}</td></tr>
      <tr><td><strong>Phone</strong></td><td>${escapeHtml(phone)}</td></tr>
      <tr><td><strong>Email</strong></td><td>${escapeHtml(email)}</td></tr>
      <tr><td><strong>Organisation</strong></td><td>${escapeHtml(organisation)}</td></tr>
      <tr><td><strong>Area of Law</strong></td><td>${escapeHtml(area)}</td></tr>
      <tr><td><strong>Brief</strong></td><td>${escapeHtml(note)}</td></tr>
      <tr><td><strong>Submitted</strong></td><td>${escapeHtml(createdAt)}</td></tr>
    </table>
  `;

  try {
    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        // Resend's shared sandbox sender — works without verifying a domain,
        // but (per Resend's current rules) can only deliver to the email
        // address on your own Resend account until you verify a domain.
        // Swap this to something like "bookings@esquireslegal.com" once
        // you've verified esquireslegal.com in Resend.
        from: 'Esquires Legal Bookings <onboarding@resend.dev>',
        to: [NOTIFY_EMAIL],
        subject: `New booking: ${name}`,
        html,
      }),
    });

    if (!resendRes.ok) {
      const errText = await resendRes.text();
      console.error('Resend error:', errText);
      return res.status(502).json({ error: 'Failed to send email' });
    }

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('notify-booking error:', err);
    return res.status(500).json({ error: 'Unexpected error' });
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}
