-- =====================================================================
-- Kueri analitik mingguan: versi BENAR vs versi SALAH pada klausa WHERE
-- Aturan Week 3: jangan membungkus kolom dengan fungsi di WHERE (non-sargable).
-- Pada tabel berpartisi, fungsi pada kolom kunci partisi juga MEMATIKAN partition pruning.
-- Jalankan: psql -d iot -f sql/04_analytics_and_explain.sql
-- =====================================================================
-- Jendela "minggu lalu" = 7 hari penuh sebelum hari ini (zona Asia/Jakarta), rentang setengah-terbuka [mulai, akhir)
SELECT (((now() AT TIME ZONE 'Asia/Jakarta')::date - 7)::timestamp AT TIME ZONE 'Asia/Jakarta') AS wk_start,
       (((now() AT TIME ZONE 'Asia/Jakarta')::date    )::timestamp AT TIME ZONE 'Asia/Jakarta') AS wk_end \gset
-- perangkat contoh = perangkat di tengah urutan (aman untuk ukuran data berapa pun)
SELECT device_id AS dev FROM devices ORDER BY device_id LIMIT 1 OFFSET (SELECT count(*) / 2 FROM devices) \gset

\echo '=== Q1 BENAR: statistik mingguan semua perangkat (rentang waktu langsung pada kolom) ==='
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT device_id, avg(metric_value) AS avg_v, max(metric_value) AS max_v, count(*) AS n
FROM sensor_logs
WHERE recorded_at >= :'wk_start' AND recorded_at < :'wk_end'
GROUP BY device_id;

\echo '=== Q1 SALAH: DATE(recorded_at) membungkus kolom -> tidak ada partition pruning ==='
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT device_id, avg(metric_value) AS avg_v, max(metric_value) AS max_v, count(*) AS n
FROM sensor_logs
WHERE DATE(recorded_at AT TIME ZONE 'Asia/Jakarta') >= (:'wk_start'::timestamptz AT TIME ZONE 'Asia/Jakarta')::date
  AND DATE(recorded_at AT TIME ZONE 'Asia/Jakarta') <  (:'wk_end'::timestamptz   AT TIME ZONE 'Asia/Jakarta')::date
GROUP BY device_id;

\echo '=== Q2 BENAR: satu perangkat, satu minggu (memakai indeks gabungan device_id, recorded_at) ==='
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON)
SELECT recorded_at, metric_value FROM sensor_logs
WHERE device_id = :dev AND recorded_at >= :'wk_start' AND recorded_at < :'wk_end'
ORDER BY recorded_at;

\echo '=== Q2 SALAH: fungsi pada recorded_at -> rentang waktu tidak bisa dipakai indeks / pruning ==='
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF, SUMMARY ON)
SELECT recorded_at, metric_value FROM sensor_logs
WHERE device_id = :dev
  AND DATE(recorded_at AT TIME ZONE 'Asia/Jakarta') >= (:'wk_start'::timestamptz AT TIME ZONE 'Asia/Jakarta')::date
  AND DATE(recorded_at AT TIME ZONE 'Asia/Jakarta') <  (:'wk_end'::timestamptz   AT TIME ZONE 'Asia/Jakarta')::date
ORDER BY recorded_at;

\echo '=== Q3 laporan mingguan per mitra (JOIN master devices; filter di kolom mentah) ==='
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
SELECT d.device_type, count(*) AS n, round(avg(l.metric_value)::numeric, 2) AS avg_v, max(l.metric_value) AS max_v
FROM devices d
JOIN sensor_logs l ON l.device_id = d.device_id
WHERE d.partner_id = 1
  AND l.recorded_at >= :'wk_start' AND l.recorded_at < :'wk_end'
GROUP BY d.device_type;
