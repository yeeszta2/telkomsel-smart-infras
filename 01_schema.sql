-- =====================================================================
-- Telkomsel Smart-Infras: skema penyimpanan data IoT (PostgreSQL 14+)
-- Bagian B - Database Schema & Storage Strategy
-- Jalankan: psql -v ON_ERROR_STOP=1 -f sql/01_schema.sql
-- =====================================================================

-- ---------- master mitra (korporasi pemilik sensor) ----------
CREATE TABLE partners (
    partner_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,   -- 4 byte
    partner_name  varchar(100) NOT NULL UNIQUE,
    contact_email varchar(120),
    created_at    timestamptz  NOT NULL DEFAULT now()
);

-- ---------- master perangkat ----------
CREATE TABLE devices (
    device_id        integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- INT 4 byte (cukup sampai 2,1 miliar)
    partner_id       integer      NOT NULL REFERENCES partners (partner_id),
    device_uid       varchar(32)  NOT NULL UNIQUE,                     -- DevEUI / IMEI / nomor seri
    device_type      varchar(20)  NOT NULL
                     CHECK (device_type IN ('SUBSTATION_TEMP', 'WATER_METER')),
    region_code      varchar(8)   NOT NULL,
    latitude         numeric(8,5),
    longitude        numeric(8,5),
    firmware_version varchar(16),
    status           varchar(10)  NOT NULL DEFAULT 'ACTIVE'
                     CHECK (status IN ('ACTIVE', 'INACTIVE', 'FAULT')),
    installed_at     timestamptz  NOT NULL DEFAULT now()
);
CREATE INDEX idx_devices_partner ON devices (partner_id);              -- laporan per mitra

-- ---------- transaksi sensor (append-only, dipartisi harian) ----------
-- Urutan kolom disusun dari tipe terlebar agar padding perataan (alignment) minimal.
CREATE TABLE sensor_logs (
    recorded_at  timestamptz NOT NULL,                                 -- 8 byte, waktu pengukuran dari perangkat
    device_id    integer     NOT NULL REFERENCES devices (device_id),  -- 4 byte, FK ke tabel master
    metric_value real        NOT NULL,                                 -- 4 byte (float4): suhu C atau debit per interval
    battery_pct  smallint    CHECK (battery_pct BETWEEN 0 AND 100),    -- 2 byte
    quality      smallint    NOT NULL DEFAULT 0,                       -- 2 byte: 0=OK, 1=diragukan, 2=error sensor
    -- Indeks gabungan sekaligus kunci utama: equality (device_id) dulu, baru range (recorded_at).
    -- recorded_at wajib ada di PK karena merupakan kunci partisi. PK juga membuat INSERT idempotent
    -- (paket MQTT QoS 1 yang terkirim ulang tidak membuat baris ganda).
    PRIMARY KEY (device_id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- CATATAN DESAIN: TIDAK memakai partisi DEFAULT. PostgreSQL menolak DETACH PARTITION ... CONCURRENTLY
-- selama ada partisi DEFAULT, padahal retensi tanpa mengunci tabel induk lebih penting. Sebagai gantinya:
--   (1) lapisan ingest memvalidasi recorded_at pada rentang [sekarang - 90 hari, sekarang + 1 hari];
--       baris di luar rentang dikirim ke antrean dead-letter (bukan ke database);
--   (2) partisi dibuat 7 hari ke depan setiap hari, dan alarm menyala bila stok partisi ke depan < 3 hari
--       (INSERT ke tanggal tanpa partisi akan GAGAL, jadi ini risiko operasional utama).

COMMENT ON TABLE sensor_logs IS 'Telemetri sensor IoT; append-only (tanpa UPDATE); partisi harian zona Asia/Jakarta';
COMMENT ON COLUMN sensor_logs.metric_value IS 'Suhu (C) atau debit per interval; total kumulatif meteran disimpan sebagai delta';
