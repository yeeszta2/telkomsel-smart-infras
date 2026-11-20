-- =====================================================================
-- Retensi: lepas partisi lebih tua dari :keep_days (bawaan 90 hari) TANPA mengunci tabel induk.
-- DETACH ... CONCURRENTLY tidak boleh di dalam transaksi/fungsi, maka dibangkitkan lewat \gexec.
-- Jalankan: psql -v keep_days=90 -f sql/05_retention_detach.sql
-- Syarat: tabel sensor_logs TIDAK boleh punya partisi DEFAULT (batasan PostgreSQL untuk DETACH CONCURRENTLY).
-- Setelah terlepas: arsipkan (COPY ke berkas terkompresi / object storage), verifikasi, lalu DROP TABLE.
-- =====================================================================
\if :{?keep_days}
\else
\set keep_days 90
\endif
SELECT format('ALTER TABLE sensor_logs DETACH PARTITION %I CONCURRENTLY', c.relname) AS stmt
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
WHERE i.inhparent = 'sensor_logs'::regclass
  AND c.relname ~ '^sensor_logs_p[0-9]{8}$'
  AND to_date(right(c.relname, 8), 'YYYYMMDD') < (now() AT TIME ZONE 'Asia/Jakarta')::date - :keep_days
ORDER BY c.relname
\gexec
