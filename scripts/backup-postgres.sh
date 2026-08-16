#!/usr/bin/env bash
# Backup Postgres TeriyaScore (Docker local ou URL DATABASE_URL).
# Usage:
#   ./scripts/backup-postgres.sh
#   DATABASE_URL=postgresql://... ./scripts/backup-postgres.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${BACKUP_DIR:-$ROOT/backups}"
mkdir -p "$OUT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="$OUT_DIR/teriyascore-$STAMP.sql.gz"

if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "[backup] pg_dump via DATABASE_URL → $FILE"
  pg_dump "$DATABASE_URL" | gzip > "$FILE"
elif docker ps --format '{{.Names}}' | grep -q '^teriyascore-postgres$'; then
  echo "[backup] pg_dump via conteneur teriyascore-postgres → $FILE"
  docker exec teriyascore-postgres pg_dump -U teriyascore teriyascore | gzip > "$FILE"
else
  echo "Ni DATABASE_URL ni conteneur teriyascore-postgres. Abort." >&2
  exit 1
fi

# Conservation : 14 derniers backups
ls -1t "$OUT_DIR"/teriyascore-*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm -f

echo "[backup] OK $(du -h "$FILE" | cut -f1)"
