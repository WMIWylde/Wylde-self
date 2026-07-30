-- RX catalog import support: wholesale cost + source tracking
alter table clinic_products add column if not exists cost numeric;
alter table clinic_products add column if not exists rx_code text;
alter table clinic_products add column if not exists order_type text; -- 'bulk' | 'patient'

-- Expand category whitelist for RX catalogs
alter table clinic_products drop constraint if exists clinic_products_category_check;
alter table clinic_products add constraint clinic_products_category_check
  check (category in ('peptide','supplement','medication','service','lab_test','glp-1','supply'));
