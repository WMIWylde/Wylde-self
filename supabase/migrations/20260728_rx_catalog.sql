-- RX catalog import support: wholesale cost + source tracking
alter table clinic_products add column if not exists cost numeric;
alter table clinic_products add column if not exists rx_code text;
alter table clinic_products add column if not exists order_type text; -- 'bulk' | 'patient'
