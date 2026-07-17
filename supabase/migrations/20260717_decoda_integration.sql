-- Decoda Health integration: patient links + webhook idempotency
create table if not exists decoda_links (
  user_id uuid primary key references auth.users(id) on delete cascade,
  decoda_patient_id text not null,
  linked_at timestamptz not null default now(),
  source text not null default 'app' check (source in ('app', 'webhook', 'manual'))
);
create index if not exists idx_decoda_links_patient on decoda_links (decoda_patient_id);

create table if not exists decoda_webhook_events (
  event_id text primary key,
  event_type text,
  received_at timestamptz not null default now()
);

-- Service-role access only (API uses admin client); no anon access.
alter table decoda_links enable row level security;
alter table decoda_webhook_events enable row level security;
