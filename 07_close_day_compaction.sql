-- =====================================================================
-- Kompaksi indeks partisi hari yang SUDAH TUTUP (tidak menerima tulis lagi), mis. kemarin.
-- Alasan: dengan kunci (device_id, recorded_at) dan laporan perangkat yang bergantian, sisipan jatuh di
-- tengah indeks sehingga halaman daun hanya terisi sekitar 62%. REINDEX merapatkannya ke sekitar 90%.
-- Jalankan: psql -v day_offset=1 -f sql/07_close_day_compaction.sql
-- =====================================================================
\if :{?day_offset}
\else
\set day_offset 1
\endif
SELECT format('REINDEX INDEX CONCURRENTLY %I',
              'sensor_logs_p' || to_char((now() AT TIME ZONE 'Asia/Jakarta')::date - :day_offset, 'YYYYMMDD') || '_pkey') AS stmt
\gexec
