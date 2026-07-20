#!/usr/bin/env bash
set -euo pipefail

repo="${GBRAIN_REPO:-/home/gbrain/brain}"
source_id="${GBRAIN_DURABILITY_SOURCE:-default}"
branch="${GBRAIN_DURABILITY_BRANCH:-main}"
install_cron="${GBRAIN_DURABILITY_INSTALL_CRON:-0}"

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
