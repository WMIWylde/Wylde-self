-- Coach memory: durable facts the AI guide learns about each user
create table if not exists coach_memory (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  fact text not null,
  category text default 'general',  -- identity | training | life | preference | general
  created_at timestamptz not null default now()
);
create index if not exists idx_coach_memory_user on coach_memory (user_id, created_at desc);

alter table coach_memory enable row level security;
create policy "own memory insert" on coach_memory for insert with check (auth.uid() = user_id);
create policy "own memory read" on coach_memory for select using (auth.uid() = user_id);
create policy "own memory delete" on coach_memory for delete using (auth.uid() = user_id);
