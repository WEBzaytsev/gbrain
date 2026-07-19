#!/usr/bin/env bash
set -euo pipefail

prepare_bind_mounts() {
  mkdir -p /home/gbrain/.gbrain /home/gbrain/brain
  chown -R gbrain:gbrain /home/gbrain
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

mode="${1:-serve}"
shift || true

wait_for_postgres
prepare_bind_mounts

case "$mode" in
  init)
    cmd=(/usr/local/bin/init.sh "$@")
    ;;
  serve)
    cmd=(
      gbrain serve --http
      --port "${GBRAIN_PORT:-3131}"
      --bind "${GBRAIN_BIND:-0.0.0.0}"
      --public-url "${GBRAIN_PUBLIC_URL:?GBRAIN_PUBLIC_URL must be set}"
      --token-ttl "${GBRAIN_TOKEN_TTL:-3600}"
      --enable-dcr
      --suppress-bootstrap-token
      "$@"
    )
    ;;
  worker)
    cmd=(
      gbrain jobs work
      --queue "${GBRAIN_WORKER_QUEUE:-default}"
      --concurrency "${GBRAIN_WORKER_CONCURRENCY:-2}"
      --max-rss "${GBRAIN_WORKER_MAX_RSS_MB:-0}"
      "$@"
    )
    ;;
  autopilot)
    rm -f /home/gbrain/.gbrain/autopilot.lock 2>/dev/null || true
    cmd=(
      gbrain autopilot
      --repo "${GBRAIN_REPO:-/home/gbrain/brain}"
      --no-worker
      --interval "${GBRAIN_AUTOPILOT_INTERVAL:-300}"
      "$@"
    )
    ;;
  federation)
    cmd=(/usr/local/bin/grant-federation.sh "$@")
    ;;
  harden)
    cmd=(/usr/local/bin/harden-brain-repo.sh "$@")
    ;;
  *)
    cmd=("$mode" "$@")
    ;;
esac

as_gbrain "${cmd[@]}"
