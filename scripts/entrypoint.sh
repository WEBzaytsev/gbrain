#!/usr/bin/env bash
set -euo pipefail

ROLE="${GBRAIN_ROLE:?GBRAIN_ROLE must be set: serve|worker|autopilot}"

prepare_bind_mounts() {
  mkdir -p /home/gbrain/.gbrain /data/brain
  chown -R gbrain:gbrain /home/gbrain/.gbrain /data/brain
}

as_gbrain() {
  exec gosu gbrain:gbrain "$@"
}

wait_for_postgres() {
  echo "[entrypoint] waiting for postgres"
  until psql "${DATABASE_URL:?DATABASE_URL must be set}" -X -v ON_ERROR_STOP=1 -c 'SELECT 1' >/dev/null 2>&1; do
    sleep 2
  done
  echo "[entrypoint] postgres ready"
}

wait_for_postgres
prepare_bind_mounts

case "$ROLE" in
  serve)
    as_gbrain gbrain serve --http \
      --port "${GBRAIN_PORT:-3131}" \
      --bind "${GBRAIN_BIND:-0.0.0.0}" \
      --public-url "${GBRAIN_PUBLIC_URL:?GBRAIN_PUBLIC_URL must be set}" \
      --token-ttl "${GBRAIN_TOKEN_TTL:-3600}" \
      --enable-dcr \
      --suppress-bootstrap-token
    ;;
  worker)
    args=(jobs work --queue "${GBRAIN_WORKER_QUEUE:-default}")
    if [[ -n "${GBRAIN_WORKER_CONCURRENCY:-}" ]]; then
      args+=(--concurrency "${GBRAIN_WORKER_CONCURRENCY}")
    fi
    if [[ -n "${GBRAIN_WORKER_MAX_RSS_MB:-}" ]]; then
      args+=(--max-rss "${GBRAIN_WORKER_MAX_RSS_MB}")
    fi
    as_gbrain gbrain "${args[@]}"
    ;;
  autopilot)
    rm -f "${HOME}/.gbrain/autopilot.lock" 2>/dev/null || true
    as_gbrain gbrain autopilot \
      --repo "${GBRAIN_REPO:-/data/brain}" \
      --no-worker \
      --interval "${GBRAIN_AUTOPILOT_INTERVAL:-300}"
    ;;
  *)
    echo "[entrypoint] unknown GBRAIN_ROLE: $ROLE" >&2
    exit 1
    ;;
esac
