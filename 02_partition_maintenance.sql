-- =====================================================================
-- Pemeliharaan partisi harian (batas hari = 00:00 Asia/Jakarta)
-- Jadwalkan ensure_sensor_log_partitions() tiap hari (pg_cron / cron + psql).
-- =====================================================================
CREATE OR REPLACE FUNCTION ensure_sensor_log_partitions(p_back integer DEFAULT 0,
                                                        p_ahead integer DEFAULT 7)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
    today   date := (now() AT TIME ZONE 'Asia/Jakarta')::date;
    d       date;
    pname   text;
    created integer := 0;
BEGIN
    FOR d IN SELECT generate_series(today - p_back, today + p_ahead, interval '1 day')::date LOOP
        pname := 'sensor_logs_p' || to_char(d, 'YYYYMMDD');
        IF to_regclass(pname) IS NULL THEN
            EXECUTE format(
                'CREATE TABLE %I PARTITION OF sensor_logs FOR VALUES FROM (%L) TO (%L)',
                pname,
                (d::timestamp)       AT TIME ZONE 'Asia/Jakarta',
                ((d + 1)::timestamp) AT TIME ZONE 'Asia/Jakarta');
            created := created + 1;
        END IF;
    END LOOP;
    RETURN created;
END $$;

-- Buat partisi hari ini sampai 7 hari ke depan:
SELECT ensure_sensor_log_partitions(0, 7) AS partisi_baru;
