#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${GBRAIN_FEDERATION_INTERVAL:-60}"

echo "[federation] waiting for postgres"
until psql "${DATABASE_URL:?DATABASE_URL must be set}" -X -v ON_ERROR_STOP=1 -c 'SELECT 1' >/dev/null 2>&1; do
  sleep 2
done

echo "[federation] enabled: all OAuth clients will read all sources every ${INTERVAL}s"

SQL="UPDATE oauth_clients
     SET federated_read = COALESCE((SELECT array_agg(id ORDER BY id) FROM sources), '{}'::text[])
     WHERE COALESCE(federated_read, '{}'::text[])
           IS DISTINCT FROM COALESCE((SELECT array_agg(id ORDER BY id) FROM sources), '{}'::text[]);"

while true; do
  psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -c "$SQL" >/dev/null || \
    echo "[federation] grant update failed; retrying in ${INTERVAL}s" >&2
  sleep "$INTERVAL"
done
