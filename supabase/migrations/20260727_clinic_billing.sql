-- Clinic billing (Stripe subscriptions). Existing clinics default to
-- 'comped' — billing is built but nobody gets blocked until enforcement
-- is turned on and statuses are set deliberately.
alter table clinic_settings add column if not exists stripe_customer_id text;
alter table clinic_settings add column if not exists stripe_subscription_id text;
alter table clinic_settings add column if not exists billing_status text not null default 'comped';
alter table clinic_settings add column if not exists billing_period_end timestamptz;
