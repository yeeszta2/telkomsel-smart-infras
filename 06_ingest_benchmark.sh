#!/usr/bin/env bash
# Uji beban tulis + bukti pencegahan deadlock. Butuh pgbench (paket postgresql-contrib).
# Pakai:  DB=iot CLIENTS=8 SECS=15 bash sql/06_ingest_benchmark.sh
set -euo pipefail
DB=${DB:-iot}; CLIENTS=${CLIENTS:-8}; SECS=${SECS:-15}; DIR=$(cd "$(dirname "$0")" && pwd)/bench
dl() { psql -d "$DB" -Atc "SELECT deadlocks FROM pg_stat_database WHERE datname = current_database()"; }
for s in ingest_unordered ingest_ordered ingest_throughput; do
  before=$(dl)
  echo "=== $s ($CLIENTS klien, ${SECS}s) ==="
  pgbench -n -f "$DIR/$s.pgbench" -c "$CLIENTS" -j "$CLIENTS" -T "$SECS" "$DB" 2>&1 | grep -E "number of transactions actually processed|tps =|number of failed" || true
  sleep 1
  echo "deadlock baru: $(( $(dl) - before ))"
done
