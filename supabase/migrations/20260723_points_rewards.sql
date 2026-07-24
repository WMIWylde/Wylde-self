-- Points economy: earn on adherence, redeem for partner discounts
create table if not exists points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  delta int not null,
  reason text,
  source text not null default 'app',
  created_at timestamptz not null default now()
);
create index if not exists idx_points_user_time on points_ledger (user_id, created_at desc);

create table if not exists rewards (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  cost int not null,
  category text,               -- 'supplements' | 'peptides' | 'providers' | 'app'
  partner text,
  active boolean not null default true,
  sort int not null default 100
);

create table if not exists reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_id uuid not null references rewards(id),
  cost int not null,
  code text not null,
  status text not null default 'issued' check (status in ('issued','used','expired','revoked')),
  created_at timestamptz not null default now()
);
create index if not exists idx_redemptions_user on reward_redemptions (user_id, created_at desc);

alter table points_ledger enable row level security;
alter table rewards enable row level security;
alter table reward_redemptions enable row level security;

-- Users may record EARNINGS only (positive deltas); spends happen server-side
create policy "earn own points" on points_ledger
  for insert with check (auth.uid() = user_id and delta > 0 and delta <= 200);
create policy "read own points" on points_ledger
  for select using (auth.uid() = user_id);
create policy "rewards are public" on rewards
  for select using (active = true);
create policy "read own redemptions" on reward_redemptions
  for select using (auth.uid() = user_id);

-- Seed catalog (placeholder partners — update titles/costs as deals land)
insert into rewards (title, description, cost, category, sort) values
  ('10% off your next supplement order', 'One-time discount code for partner supplement brands.', 500, 'supplements', 10),
  ('15% off peptide protocols', 'Discount on your clinic''s peptide protocol pricing.', 1000, 'peptides', 20),
  ('$25 off a provider consult', 'Credit toward a session with a partner provider.', 1500, 'providers', 30),
  ('Early access: next Wylde feature', 'Unlock the next premium feature before everyone else.', 750, 'app', 40)
on conflict do nothing;
