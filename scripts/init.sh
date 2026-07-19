#!/usr/bin/env bash
set -euo pipefail

prepare_bind_mounts() {
  mkdir -p /home/gbrain/.gbrain /data/brain
  chown -R gbrain:gbrain /home/gbrain/.gbrain /data/brain
}

as_gbrain() {
  gosu gbrain:gbrain "$@"
}

wait_for_postgres() {
  echo "[init] waiting for postgres"
  until psql "${DATABASE_URL:?DATABASE_URL must be set}" -X -v ON_ERROR_STOP=1 -c 'SELECT 1' >/dev/null 2>&1; do
    sleep 2
  done
  echo "[init] postgres ready"
}

run_init_if_needed() {
  if [[ -f "/home/gbrain/.gbrain/config.json" ]]; then
    echo "[init] config exists, skipping gbrain init"
    return
  fi

  echo "[init] running gbrain init"
  cmd=(gbrain init --non-interactive --url "$DATABASE_URL" --schema-pack "${GBRAIN_SCHEMA_PACK:-gbrain-base-v2}")

  if [[ "${GBRAIN_INIT_NO_EMBEDDING:-0}" == "1" ]]; then
    cmd+=(--no-embedding)
  else
    cmd+=(--embedding-model "${GBRAIN_INIT_EMBEDDING_MODEL:-openai:text-embedding-3-large}")
    cmd+=(--embedding-dimensions "${GBRAIN_INIT_EMBEDDING_DIMENSIONS:-1536}")
  fi

  if [[ "${GBRAIN_INIT_SKIP_EMBED_CHECK:-0}" == "1" ]]; then
    cmd+=(--skip-embed-check)
  fi

  as_gbrain "${cmd[@]}"
}

register_local_sources() {
  shopt -s nullglob
  for d in /data/brain/*/; do
    [[ -d "$d" ]] || continue
    id="$(basename "$d")"
    if [[ "$id" == .* ]]; then
      echo "[init] skip hidden source directory: $id"
      continue
    fi
    echo "[init] registering local source: $id -> $d"
    as_gbrain gbrain sources add "$id" --path "$d" --name "$id" --federated || true
  done
}

wait_for_postgres
prepare_bind_mounts
run_init_if_needed
register_local_sources

as_gbrain gbrain sources list || true
echo "[init] done"
