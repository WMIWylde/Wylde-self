-- ═══ Wylde schema verification ═══
-- Paste and run anytime. Reports which expected tables/columns are MISSING
-- from this database. Empty result = fully migrated. Safe: read-only.
with expected(tbl, col) as (values
  ('workout_set_logs', 'id'),
  ('workout_set_logs', 'target_reps'),
  ('points_ledger', 'delta'),
  ('rewards', 'cost'),
  ('reward_redemptions', 'code'),
  ('badges', 'badge_id'),
  ('feedback', 'message'),
  ('coach_memory', 'fact'),
  ('decoda_links', 'decoda_patient_id'),
  ('decoda_webhook_events', 'event_id'),
  ('clinic_settings', 'join_code'),
  ('clinic_settings', 'billing_status'),
  ('clinic_settings', 'stripe_customer_id'),
  ('clinic_products', 'is_in_stock'),
  ('clinic_team_members', 'member_user_id'),
  ('care_invite_codes', 'used_by'),
  ('care_relationships', 'clinic_name')
)
select e.tbl as missing_table_or_column, e.col
from expected e
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = e.tbl and c.column_name = e.col
where c.column_name is null
order by e.tbl;
