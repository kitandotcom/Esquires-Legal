# Esquires' Legal

A responsive static website for Esquires' Legal with Supabase-backed content, staff authentication, blog management, counsel profiles, and consultation bookings.

## Security setup

The browser contains only the Supabase **publishable/anon key**. That key is designed for browser use and is constrained by Row Level Security. Supabase Auth handles password hashing and session management; this site never stores passwords itself. Never put a `service_role` key, database password, Resend key, or webhook secret in `config.js`.

Configure these **server-only** Vercel environment variables before deploying:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_WEBHOOK_SECRET`
- `RESEND_API_KEY`
- `NOTIFY_EMAIL`

Use `.env.example` as the variable checklist. Do not commit `.env` files.

## Database migration

Run `schema.sql` in the Supabase SQL editor. It:

- creates the `profiles` role table and role helper;
- restricts bookings to staff reads/updates and admin deletes;
- removes the anonymous bookings insert policy because public submissions now use the throttled `/api/submit-booking` endpoint;
- permits editors to submit pending blog posts while only admins can publish/delete and edit site content;
- ensures anonymous visitors can read only published blog posts.

After running it, create one `profiles` row for each staff account using the matching Supabase Auth user ID and either `admin` or `editor` role.

## Local smoke test

This repository has no package manager dependencies. Serve it with:

```bash
python3 -m http.server 4173
```

The production deployment uses Vercel serverless functions under `api/` and the security headers in `vercel.json`.

## Routes

- `/` — public site
- `/admin` — staff login and admin dashboard
- `/submit` — editor dashboard
- `/api/submit-booking` — validated, rate-limited booking submission
- `/api/notify-booking` — authenticated Supabase webhook email notification
