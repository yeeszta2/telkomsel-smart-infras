# telkomsel-smart-infras


# Telkomsel Smart-Infras: Connectivity & Storage Design for IoT App

Cetak biru infrastruktur hulu-hilir untuk platform IoT enterprise (Weekly Assignment, unit *Network & Database Management -
Architecture Governance*). **Seluruh nama, IP, dan angka beban adalah asumsi/simulasi untuk praktikum.**

## Peta tugas ke berkas

| Ketentuan tugas | Berkas |
|---|---|
| A. Visual Topology Layering (Edge, Gateway, LB, App; Three-Tier DC) | `diagrams/network-topology.svg/.png/.drawio` |
| A. Network Segmentation & IP Plan (VLAN IoT Ingress, VLSM) | `data/ipplan.csv`, `data/addresses.csv`, `scripts/netplan.py` |
| B. ERD Crow's Foot + tipe data hemat memori | `diagrams/erd.svg/.png/.drawio`, `sql/01_schema.sql` |
| B. Composite Index + Table Partitioning | `sql/01_schema.sql`, `sql/02_partition_maintenance.sql` |
| Hindari kesalahan klausa WHERE | `sql/04_analytics_and_explain.sql` (benar vs salah + EXPLAIN) |
| Final Check: deadlock prevention, low latency | `sql/06_ingest_benchmark.sh`, `data/acl.csv`, diagram |
| Laporan PDF | `reports/Telkomsel_Smart-Infras_Connectivity_Storage_Design.pdf` |
| Catatan belajar | `docs/learning-notes.md` |

## Cara menjalankan

```bash
python scripts/netplan.py              # validasi VLSM: tumpang tindih, prefix terkecil, IP unik
python scripts/sizing.py               # model kapasitas (pesan/detik, GB/hari, retensi)
python -m unittest discover -s tests   # unit test
python scripts/generate_diagrams.py --png          # SVG, drawio, PNG (PNG butuh: pip install cairosvg)
python scripts/build_report.py                      # PDF (butuh: pip install reportlab)

# Lab PostgreSQL 14+ (diuji di 16.15)
createdb iot
psql -d iot -v ON_ERROR_STOP=1 -f sql/01_schema.sql
psql -d iot -v ON_ERROR_STOP=1 -f sql/02_partition_maintenance.sql
psql -d iot -v ON_ERROR_STOP=1 -v n_devices=2000 -v days=14 -f sql/03_seed_demo_data.sql   # 10 juta baris, +/- 75 dtk
psql -d iot -f sql/04_analytics_and_explain.sql
DB=iot CLIENTS=8 SECS=15 bash sql/06_ingest_benchmark.sh                                   # butuh pgbench
psql -d iot -v day_offset=3 -f sql/07_close_day_compaction.sql
psql -d iot -v keep_days=10 -f sql/05_retention_detach.sql
```

## Hasil lab terukur (PostgreSQL 16.15 di sandbox; angka bervariasi per mesin)

| Pengukuran | Hasil |
|---|---|
| Ukuran baris `sensor_logs` | heap 52,2 B; indeks PK 45,7 B (sisip real-time) dan 31,6 B setelah `REINDEX` |
| Statistik mingguan, `WHERE` benar vs `DATE(recorded_at)` | 7 vs 23 partisi dipindai; 1,76 dtk vs 6,38 dtk (3,6x) |
| Ingest 8 klien, batch 1.000 baris | ~99 ribu baris/dtk (kebutuhan 5 ribu/dtk pada 5x tumbuh) |
| Deadlock, 8 klien rebutan 50 kunci sama | 6 deadlock (urutan acak) vs 0 (urutan terurut) dalam 15 dtk |
| Retensi `DETACH PARTITION CONCURRENTLY` | 4 partisi dilepas tanpa mengunci tabel induk |

## Temuan penting selama pengujian

- PostgreSQL menolak `DETACH ... CONCURRENTLY` bila ada partisi `DEFAULT`; desain awal diubah (tanpa DEFAULT, validasi waktu di ingest).
- Indeks `(device_id, recorded_at)` menjadi ~45% lebih besar pada pola tulis nyata (halaman daun ~62% penuh); kompaksi dengan `REINDEX CONCURRENTLY` pada partisi yang sudah tutup.

## Membuka diagram

`.drawio` dibuka di https://app.diagrams.net (shape Cisco `mxgraph.cisco.*` dan panah ER bawaan). Dari sana dapat diekspor atau
dirapikan di Visio/Lucidchart sesuai standar unit.
