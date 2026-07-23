-- Tester feedback, tied to real accounts (unlike anonymous TestFlight feedback)
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  message text not null,
  platform text,          -- 'ios' | 'web'
  build text,             -- app build/version
  screen text,            -- where they were when sending
  created_at timestamptz not null default now()
);
create index if not exists idx_feedback_user_time on feedback (user_id, created_at desc);

alter table feedback enable row level security;
create policy "insert own feedback" on feedback
  for insert with check (auth.uid() = user_id);
create policy "read own feedback" on feedback
  for select using (auth.uid() = user_id);
