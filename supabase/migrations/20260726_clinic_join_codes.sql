-- Permanent clinic join codes + team member linkage
alter table clinic_settings add column if not exists join_code text unique;
alter table care_invite_codes add column if not exists used_by uuid;
alter table care_invite_codes add column if not exists used_at timestamptz;
alter table clinic_team_members add column if not exists member_user_id uuid references auth.users(id);
create index if not exists idx_team_member_email on clinic_team_members (email);
