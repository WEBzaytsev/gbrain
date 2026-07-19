#!/usr/bin/env bash
set -euo pipefail

repo="${GBRAIN_REPO:-/home/gbrain/brain}"
source_id="${GBRAIN_DURABILITY_SOURCE:-default}"
branch="${GBRAIN_DURABILITY_BRANCH:-main}"
install_cron="${GBRAIN_DURABILITY_INSTALL_CRON:-0}"

# `docker compose exec` starts ad-hoc commands as the image user (root) because
# the entrypoint needs root briefly to prepare bind mounts before `gosu gbrain`.
# If harden runs as root, native GBrain writes a root-owned 0600 credential store
# under /home/gbrain/.gbrain; later app-triggered hooks run as uid 10001 and
# cannot read it, so auto-push becomes LOCAL-ONLY. Defensively normalize the
# mounted state and re-exec as the runtime user before touching Git credentials.
if [[ "$(id -u)" -eq 0 ]]; then
  mkdir -p /home/gbrain/.gbrain "$repo"
  chown -R gbrain:gbrain /home/gbrain/.gbrain "$repo"
  exec gosu gbrain:gbrain "$0" "$@"
fi

if [[ ! -d "$repo/.git" ]]; then
  echo "[durability] not a git repo: $repo" >&2
  exit 1
fi

# Docker exec defaults to root, but the mounted repo belongs to the gbrain user.
# This script is normally invoked through entrypoint, which drops to gbrain first.
git -C "$repo" status --short >/dev/null

echo "[durability] anchoring source $source_id -> $repo"
gbrain sync \
  --source "$source_id" \
  --repo "$repo" \
  --no-pull \
  --no-embed \
  --no-extract \
  --yes

if [[ -z "${GBRAIN_GITHUB_PAT:-}" ]]; then
  echo "[durability] GBRAIN_GITHUB_PAT is empty; source is anchored, harden skipped" >&2
  echo "[durability] set GBRAIN_GITHUB_PAT in the ignored .env/secret env and rerun this command" >&2
  exit 2
fi

harden_args=(sources harden "$source_id" --branch "$branch" --json)
if [[ "$install_cron" != "1" ]]; then
  harden_args+=(--no-cron)
fi

echo "[durability] running native gbrain harden for $source_id on $branch"
gbrain "${harden_args[@]}"
