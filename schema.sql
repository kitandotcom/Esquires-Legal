-- ---------------------------------------------------------------------------
-- Esquires' Legal — database schema
-- ---------------------------------------------------------------------------
-- Run this once in the Supabase SQL Editor (Project -> SQL Editor -> New
-- query -> paste this whole file -> Run). It is idempotent and safe to
-- re-run: it will not duplicate data or clobber existing bookings.
--
-- Tables:
--   bookings      already exists live (written to by the public consultation
--                 form). This script adds a `status` column and — important —
--                 TIGHTENS row-level security. Today anon SELECT is open
--                 (anyone with the public anon key can read all bookings);
--                 after this runs, only a signed-in admin can read/update/
--                 delete bookings, while the public form can still insert.
--   blog_posts    new. Publicly readable; only a signed-in admin can write.
--   site_content  new. Key/value(jsonb) store for the editable sections of
--                 the public site (hero, stats, firm, foundation, practice,
--                 advisory, leadership, contact, footer, closing). Publicly
--                 readable; only a signed-in admin can write. Seeded below
--                 with the copy that is already live on the site, so nothing
--                 changes on the public page until the admin edits something.
--
-- "Signed-in admin" = anyone authenticated via Supabase Auth. There is no
-- self-serve sign-up anywhere on the site, so the only account that can ever
-- exist is the one created for the admin.
-- ---------------------------------------------------------------------------

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- bookings
-- ---------------------------------------------------------------------------
create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  phone text,
  email text,
  organisation text,
  area text,
  note text
);

alter table public.bookings add column if not exists status text not null default 'new';

alter table public.bookings enable row level security;

-- Drop every existing policy on bookings (unknown prior state — e.g. an
-- open "allow all" policy from the Supabase quick-start) so nothing
-- permissive is left combined (OR'd) with the restrictive ones below.
do $$
declare
  pol record;
begin
  for pol in select policyname from pg_policies where schemaname = 'public' and tablename = 'bookings' loop
    execute format('drop policy if exists %I on public.bookings', pol.policyname);
  end loop;
end $$;

create policy "bookings_insert_public" on public.bookings
  for insert to anon, authenticated with check (true);

create policy "bookings_select_admin" on public.bookings
  for select to authenticated using (true);

create policy "bookings_update_admin" on public.bookings
  for update to authenticated using (true) with check (true);

create policy "bookings_delete_admin" on public.bookings
  for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- shared updated_at trigger
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------------
-- blog_posts
-- ---------------------------------------------------------------------------
create table if not exists public.blog_posts (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  title text not null,
  author text not null,
  content text not null
);

alter table public.blog_posts enable row level security;

drop trigger if exists blog_posts_set_updated_at on public.blog_posts;
create trigger blog_posts_set_updated_at
  before update on public.blog_posts
  for each row execute function public.set_updated_at();

drop policy if exists "blog_select_public" on public.blog_posts;
create policy "blog_select_public" on public.blog_posts
  for select to anon, authenticated using (true);

drop policy if exists "blog_insert_admin" on public.blog_posts;
create policy "blog_insert_admin" on public.blog_posts
  for insert to authenticated with check (true);

drop policy if exists "blog_update_admin" on public.blog_posts;
create policy "blog_update_admin" on public.blog_posts
  for update to authenticated using (true) with check (true);

drop policy if exists "blog_delete_admin" on public.blog_posts;
create policy "blog_delete_admin" on public.blog_posts
  for delete to authenticated using (true);

-- ---------------------------------------------------------------------------
-- site_content
-- ---------------------------------------------------------------------------
create table if not exists public.site_content (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.site_content enable row level security;

drop trigger if exists site_content_set_updated_at on public.site_content;
create trigger site_content_set_updated_at
  before update on public.site_content
  for each row execute function public.set_updated_at();

drop policy if exists "content_select_public" on public.site_content;
create policy "content_select_public" on public.site_content
  for select to anon, authenticated using (true);

drop policy if exists "content_write_admin" on public.site_content;
create policy "content_write_admin" on public.site_content
  for all to authenticated using (true) with check (true);

-- ---------------------------------------------------------------------------
-- site_content seed data — mirrors the copy already live in index.html.
-- Uses ON CONFLICT DO NOTHING so re-running this script never overwrites
-- content the admin has since edited.
-- ---------------------------------------------------------------------------

insert into public.site_content (key, value) values
('hero', $j$
{
  "eyebrow": "Esquires' Legal — Nigeria & International",
  "title": "Counsel for consequential matters.",
  "sub": "A chambers of Advocates, Notaries and Arbitrators built for institutions, government and enterprise — with a presence across Nigeria and associate offices in Douala, London, New York and Houston.",
  "cta_primary": "Our Practice",
  "cta_secondary": "Book a Consultation"
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('stats', $j$
[
  {"value": "20", "suffix": "+", "label": "Years of Practice"},
  {"value": "16", "suffix": "", "label": "Practice Areas"},
  {"value": "5", "suffix": "", "label": "Global Offices"},
  {"value": "12", "suffix": "", "label": "States, Nationwide"}
]
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('firm', $j$
{
  "title_pre": "A dynamic chambers, ",
  "title_em": "built on precedent.",
  "paragraphs": [
    "Esquires' Legal is a dynamic set of Chambers with highly experienced legal practitioners, Arbitrators and Notaries Public based primarily in Nigeria — an international law firm with offices in Lagos and Abuja, and associate offices in Douala, London, New York and Houston.",
    "Our membership of the African Bar Association gives us a wide network of international associates across the African continent. We advise corporate institutions, government agencies and private clients with the same rigour we would bring to a sovereign matter."
  ],
  "quote": "\"Integrity in Efficacy.\"",
  "quote_attrib": "— The Firm's Motto"
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('foundation', $j$
{
  "title_pre": "Mission, Vision ",
  "title_em": "& Philosophy.",
  "items": [
    {"idx": "MISSION", "head": "To provide superior, bespoke legal service", "body": "To provide superior bespoke legal services and advisory solutions globally that meet unique challenges and exceed stated expectations, in accordance with the highest professional standards and ethics."},
    {"idx": "VISION", "head": "Uncompromising service, beyond the legal frame", "body": "To satisfy clients with uncompromising professional legal services, including other areas of enterprise and endeavour related to, but outside, the legal framework."},
    {"idx": "PHILOSOPHY", "head": "Practical advice, delivered on time, on budget", "body": "We draw from a wide pool of expertise to deliver specialised, personalised service — practical yet innovative, performed on time and on budget, with the client always in mind. Each brief is managed closely by a partner or associate responsible for the full relationship."}
  ]
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('practice', $j$
{
  "title_pre": "What We ",
  "title_em": "Practice.",
  "items": [
    {"idx": "01", "head": "Corporate Law & Secretarial", "body": "Business and commercial law; commercial transactions, mergers & acquisitions, management buy-out/in; international trade, corporate finance and securities. Full company secretarial services, and all pre- and post-incorporation work for corporates, NGOs and trustees."},
    {"idx": "02", "head": "Real Property & Conveyancing", "body": "Sale, purchase, mortgage and re-mortgage; commercial and industrial leasing; real estate financing and development, for private and institutional landholders."},
    {"idx": "03", "head": "Maritime, Admiralty & Shipping", "body": "A strategically positioned Nigerian maritime and admiralty practice serving international shipowners, charterers, marine insurers, P&I Clubs and offshore operators."},
    {"idx": "04", "head": "Legal & Legislative Drafting", "body": "Specialist legal and legislative draughting — agreements, MOUs, deeds and settlements — prepared and consulted upon across a wide spectrum of transactions."},
    {"idx": "05", "head": "Arbitration, ADR & Mediation", "body": "Arbitration, conciliation and negotiation, including international arbitration, mediation and settlement of disputes — principally in admiralty, maritime and commercial matters."},
    {"idx": "06", "head": "General Litigation", "body": "A strong litigation practice representing clients before all courts of record, up to the apex court of the land — the Supreme Court of Nigeria."},
    {"idx": "07", "head": "Intellectual Property", "body": "Copyrights, patents and trademarks — litigating disputed marks, and advising on the protection and commercial exploitation of patents and copyrights."},
    {"idx": "08", "head": "Energy & Power", "body": "Licensing of companies with NERC and NBET; acting for DISCOs and alternative energy companies across the regulatory lifecycle."},
    {"idx": "09", "head": "Notarial Services", "body": "Bespoke notary services to clientele ranging from corporate institutions to individuals, including authentication, certification and bills of exchange."},
    {"idx": "10", "head": "Media, Entertainment & Sports", "body": "Specialised legal services across media, entertainment and sports, including representation in proceedings before the Court of Arbitration for Sport (CAS)."},
    {"idx": "11", "head": "Immigration & Nationality", "body": "Over 20 years' experience handling immigration and visa matters across jurisdictions in Europe, the Americas and Africa."},
    {"idx": "12", "head": "Consumer Protection & Anti-trust", "body": "A fairly novel area in Nigerian law. We actively represent clients and petitioners before the Federal Competition and Consumer Protection Commission (FCCPC)."},
    {"idx": "13", "head": "Family Law", "body": "Family responsibility proceedings, cohabitation contracts, child and spousal support, divorce, adoption and custody matters."},
    {"idx": "14", "head": "Customary Law & Practice", "body": "Customary law practice and custom, with pragmatic, traditional application to marriage, land, inheritance and ancillary matters."},
    {"idx": "15", "head": "Proof Reading & Editing", "body": "Assisting authors in editing and proofing their works, for an international clientele spanning the globe."},
    {"idx": "16", "head": "Other Areas", "body": "Education law, wills and probate, housing law (landlord and tenancy), information and communications technology, and class actions."}
  ]
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('advisory', $j$
{
  "title_pre": "Financial & Corporate ",
  "title_em": "Advisory.",
  "paragraphs": [
    "Beyond litigation and drafting, the Firm advises on international trade, corporate finance and securities — structuring transactions, managing pre- and post-incorporation work, and acting as company secretary to corporate clientele across sectors.",
    "We are equally at home advising a government agency as we are a multinational — the same standard of diligence applies regardless of the size of the balance sheet."
  ],
  "served": [
    {"k": "Private", "v": "Corporates & Trustees"},
    {"k": "Institutional", "v": "Banks, Insurers, DFIs"},
    {"k": "Government", "v": "Agencies & MDAs"}
  ]
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('leadership', $j$
{
  "title_pre": "Principal & Advisory ",
  "title_em": "Counsel.",
  "members": [
    {"initials": "AO", "name": "Austin J. Otah", "title": "Principal Counsel", "bio": "PRINCIPAL COUNSEL\nLL.B (Hons), LL.M, Notary Public, CIArb.\nPrincipal Consulting Counsel and Chief Consulting Officer of Esquires' Legal. A dually qualified legal practitioner with over three decades of experience across maritime, corporate, and international commercial law. Called to the Nigerian Bar in 1990, he holds a Master's Degree in Law from London Guildhall University and is an Associate Member of the Chartered Institute of Arbitrators. A published author and Roster of Counsel for the African Court on Human and Peoples' Rights, he has represented clients before the Court of Arbitration for Sport and regularly appears as a legal analyst on Nigerian television and radio."},
    {"initials": "VN", "name": "Sen. Victor Ndoma-Egba", "title": "Advisory Counsel · OFR, CON, SAN", "bio": "ADVISORY COUNSEL\nOFR, CON, SAN.\nFormer Senator of the Federal Republic of Nigeria (2003-2015) and Chairman of the Niger Delta Development Corporation. Founder and Senior Partner of Ndoma-Egba, Ebri & Co. Holds the distinction of being the first and only person elevated to the rank of Senior Advocate of Nigeria from the National Assembly. Member of the London Court of International Arbitration, International Bar Association, and Body of Benchers. Brings unparalleled expertise in governance, privatization, and public policy to the Firm."},
    {"initials": "CC", "name": "Prof. Charles S. Chatterjee", "title": "Advisory Counsel", "bio": "ADVISORY COUNSEL\nLL.M, Ph.D, Barrister (England & Wales).\nA foremost international commercial law specialist and practising barrister in England and Wales since 1994. Studied at the University of Cambridge and University of London, and held a professorial position at London Metropolitan University. Currently a Senior Associate Fellow at Warwick University and Associate Fellow of the Institute of Advanced Legal Studies, University of London. Advises on complex cross-border commercial matters including banking, trade, shipping, and insurance."},
    {"initials": "EE", "name": "Elozino Eteghrara", "title": "Snr. External Associate", "bio": "SENIOR EXTERNAL ASSOCIATE\nLL.B, BL.\nA maritime and corporate commercial law specialist with deep expertise in shipping, oil and gas, real estate, and employment law. Has served as Head of Chambers at a top maritime law firm and as managing-editor of the Admiralty Law Reports of Nigeria. Acts as a joint expert/consultant in Cabotage law, procedure and practice in Nigeria, and has provided expert reports for Covington & Burling LLP, UK. Represents multinational and local companies at trial and appellate Courts."},
    {"initials": "MI", "name": "Marvin Ibem", "title": "Senior Associate", "bio": "SENIOR ASSOCIATE\nLL.B, B.L. \nSenior Associate with extensive experience in commercial litigation, advising and representing clients in a broad range of complex commercial disputes. Renowned for his analytical insight, strategic thinking and unwavering commitment to excellence, Marvin is dedicated to delivering practical, client-focused legal solutions with the highest standards of professionalism and integrity."},
    {"initials": "RA", "name": "Richard H. John Aboki", "title": "Associate Consultant", "bio": "ASSOCIATE CONSULTANT\nLL.B, BL, ACMS, MIAD, LL.M, Ph.D.\nCalled to the Nigerian Bar in 1990 with a Master's Degree in International Affairs and Diplomacy. A Fellow of the Institute of Industrialists and Corporate Administration and former Managing Director/CEO of Kaduna State Development Property Company Limited. Brings extensive experience in research, legal coordination, and private sector management to the Firm's advisory practice."},
    {"initials": "OO", "name": "Oladele Osinuga", "title": "Associate Consultant", "bio": "ASSOCIATE CONSULTANT\nB.A, LL.B, BL, M.A, LL.M.\nAn internationally recognized legal expert admitted to the List of Counsel for the Kosovo Specialist Chambers (The Hague) and the List of Assistants to Counsel for the International Criminal Court. Served as Prosecution Advisor for the Pan American Development Foundation and Expert Consultant for the United Nations Development Programme. Brings extensive experience in international criminal law, human rights, and cross-border litigation."},
    {"initials": "GO", "name": "Godwin Okri", "title": "Real Estate Specialist", "bio": "INTERNATIONAL REAL ESTATE SPECIALIST\nLL.B (Sheffield).\nA lawyer, author, and international real estate consultant licensed as a Realtor in Florida State, USA. Author of the bestselling book 'Investing in Property with Strategy' and host of The Okri Property Show (TOPS) television series. Brings extensive experience in international property transactions across the UK, Europe, USA, and Nigeria."},
    {"initials": "TN", "name": "Nkwayep Tiwo Noffé", "title": "International Associate · Cameroon", "bio": "INTERNATIONAL ASSOCIATE · CAMEROON\nDouble Masters in Law (Disputes and Commercial Arbitration; Business Law). Called to the Nigerian Bar (2014) and Cameroon Bar (2015). ADR specialist and Founding Partner of Marcella & Co Law Firm, a bilingual corporate and business transactions-oriented firm. Provides legal advice to multinational corporations including General Electric and advises on cross-border transactions, oil and gas, and maritime law matters."},
    {"initials": "KM", "name": "Kyenret Comfort Mimang", "title": "External Associate", "bio": "EXTERNAL ASSOCIATE\nLL.B, BL.\nCalled to the Nigerian Bar in 2017. A dedicated practitioner with special interest in Intellectual Property Protection, International Business Law, Commercial Practice, and Corporate Governance. Member of the Nigerian Bar Association, Unity Bar, and has contributed to legal education through radio programs on nation-building and legal awareness."},
    {"initials": "TO", "name": "Toluwani Ibukun Onifade", "title": "Associate", "bio": "ASSOCIATE\nLL.B, BL.\nCalled to the Nigerian Bar in 2016. Associate Member of the Institute of Chartered Mediators and Conciliators. Member of the Nigerian Bar Association, Unity Bar Abuja. Specializes in Litigation, Corporate Matters, Alternative Dispute Resolution, Commercial Practice, and Corporate Governance."},
    {"initials": "EO", "name": "Esther Adebola Olanipekun", "title": "Associate", "bio": "ASSOCIATE\nLL.B (Hons), BL.\nCalled to the Nigerian Bar in 2017 with second class upper honours from Igbinedion University. Previously interned at the chambers of Dayo Akinlaja (SAN) and George Ikoli (SAN). Specializes in Litigation, Corporate Law, Real Estate, and Arbitration, with a particular interest in criminal law and criminology."}
  ]
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('contact', $j$
{
  "title_pre": "Instruct the ",
  "title_em": "Firm.",
  "offices": [
    {"flag": "Abuja — Main Office", "addr": "1st Floor, B Wing, Park N Shop Bus. Centre, No. 24 Aminu Kano Crescent, Wuse II, Abuja, Nigeria."},
    {"flag": "Lagos, Nigeria", "addr": "Associate Chambers, Lagos."},
    {"flag": "London, United Kingdom", "addr": "98 Coldharbour Lane, Camberwell, London SE5 9PU."},
    {"flag": "New York, USA", "addr": "18 East Broadway, Suite 600A, New York 10013."},
    {"flag": "Douala, Cameroon & Houston, USA", "addr": "Associate offices."}
  ]
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('footer', $j$
{
  "tagline": "Advocates, Notaries & Arbitrators. A dynamic chambers based in Nigeria, with associate offices across Africa, Europe and North America.",
  "phone": "+234 (0) 81 5047 0073",
  "email": "info@esquireslegal.com",
  "hours": "Mon–Fri, 9:00–18:00",
  "chambers": ["Lagos · Abuja", "Douala · London", "New York · Houston"],
  "copyright": "© 2026 Esquires' Legal. BN 2003538.",
  "associate_chambers": "Associate Chambers: Lagos, Kano, Kaduna, Plateau, Enugu, Delta, Edo, Rivers, Cross-River, Akwa-Ibom, Kwara & Oyo States."
}
$j$::jsonb)
on conflict (key) do nothing;

insert into public.site_content (key, value) values
('closing', $j$
{
  "quote": "\"The ordinary person deserves the same quality of counsel as the state.\""
}
$j$::jsonb)
on conflict (key) do nothing;
  
