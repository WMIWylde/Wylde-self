-- Workout set logs: powers progressive overload + adherence analytics
create table if not exists workout_set_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  exercise_name text not null,
  weight numeric not null default 0,
  reps int not null default 0,
  target_reps int,
  day_focus text,
  logged_at timestamptz not null default now()
);
create index if not exists idx_wsl_user_ex_time on workout_set_logs (user_id, exercise_name, logged_at desc);

alter table workout_set_logs enable row level security;
create policy "insert own set logs" on workout_set_logs
  for insert with check (auth.uid() = user_id);
create policy "read own set logs" on workout_set_logs
  for select using (auth.uid() = user_id);
