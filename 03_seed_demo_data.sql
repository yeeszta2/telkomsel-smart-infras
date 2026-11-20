-- =====================================================================
-- Data demo untuk lab (BUKAN produksi). Ukuran dapat diubah lewat variabel psql:
--   psql -v n_devices=2000 -v days=7 -f sql/03_seed_demo_data.sql
-- Bawaan: 2.000 perangkat x 7 hari x 360 sampel/hari = 5,04 juta baris.
-- =====================================================================
\if :{?n_devices}
\else
\set n_devices 2000
\endif
\if :{?days}
\else
\set days 7
\endif

INSERT INTO partners (partner_name, contact_email)
VALUES ('PLN Distribusi (simulasi)', 'noc@pln-sim.example'),
       ('PDAM Tirta (simulasi)',      'noc@pdam-sim.example'),
       ('Industri Mitra (simulasi)',  'noc@mitra-sim.example');

INSERT INTO devices (partner_id, device_uid, device_type, region_code, latitude, longitude, firmware_version)
SELECT 1 + (g % 3),
       'DEV-' || lpad(g::text, 8, '0'),
       CASE WHEN g % 2 = 0 THEN 'SUBSTATION_TEMP' ELSE 'WATER_METER' END,
       (ARRAY['JBR','JTG','JTM','BTN','SMU'])[1 + g % 5],
       -6 - (g % 300) / 100.0, 106 + (g % 400) / 100.0, 'v1.4.2'
FROM generate_series(1, :n_devices) g;

SELECT ensure_sensor_log_partitions(:days, 1);

\timing on
INSERT INTO sensor_logs (recorded_at, device_id, metric_value, battery_pct, quality)
SELECT ((((now() AT TIME ZONE 'Asia/Jakarta')::date - g.day_off)::timestamp) AT TIME ZONE 'Asia/Jakarta')
         + s.n * interval '240 seconds' + (d.device_id % 240) * interval '1 second',
       d.device_id,
       (20 + random() * 10)::real,
       (50 + random() * 50)::smallint,
       0
FROM generate_series(1, :days) AS g(day_off)
CROSS JOIN devices d
CROSS JOIN generate_series(0, 359) AS s(n);
\timing off

VACUUM ANALYZE sensor_logs;
VACUUM ANALYZE devices;
