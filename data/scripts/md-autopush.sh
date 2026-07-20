#!/usr/bin/env bash
set -euo pipefail

repo="${GBRAIN_MD_AUTOPUSH_REPO:-${GBRAIN_REPO:-/home/gbrain/brain}}"
remote="${GBRAIN_MD_GIT_REMOTE:-origin}"
remote_url="${GBRAIN_MD_GIT_REMOTE_URL:-https://github.com/WEBzaytsev/gbrain-md.git}"
branch="${GBRAIN_MD_GIT_BRANCH:-main}"
interval="${GBRAIN_MD_AUTOPUSH_INTERVAL:-300}"
log="${GBRAIN_MD_AUTOPUSH_LOG:-/home/gbrain/.gbrain/md-autopush.log}"
askpass="${GBRAIN_MD_AUTOPUSH_ASKPASS:-/home/gbrain/.gbrain/git-askpass-md-autopush.sh}"
username="${GBRAIN_MD_GIT_USERNAME:-x-access-token}"
commit_prefix="${GBRAIN_MD_AUTOPUSH_COMMIT_PREFIX:-chore(gbrain): autopush brain}"

token_present() { [ -n "${GBRAIN_MD_GIT_TOKEN:-}" ]; }
log_line() { mkdir -p "$(dirname "$log")"; printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$log"; }

write_askpass() {
  mkdir -p "$(dirname "$askpass")"
  umask 077
  cat >"$askpass" <<'ASKPASS'
#!/usr/bin/env bash
case "${1:-}" in
  *Username*) printf '%s\n' "${GBRAIN_MD_GIT_USERNAME:-x-access-token}" ;;
  *Password*) printf '%s\n' "${GBRAIN_MD_GIT_TOKEN:-}" ;;
  *) printf '\n' ;;
esac
ASKPASS
  chmod 700 "$askpass"
}

run_once() {
  if [ ! -d "$repo/.git" ]; then
    log_line "skip: not a git repo: $repo"
    return 0
  fi
  if ! token_present; then
    log_line "skip: GBRAIN_MD_GIT_TOKEN is empty"
    return 0
  fi

  write_askpass
  export GIT_ASKPASS="$askpass"
  export GIT_TERMINAL_PROMPT=0
  export GBRAIN_MD_GIT_USERNAME="$username"

  cd "$repo"
  git config --global --add safe.directory "$repo" >/dev/null 2>&1 || true
  git config user.name "${GBRAIN_MD_GIT_AUTHOR_NAME:-GBrain MD Autopush}"
  git config user.email "${GBRAIN_MD_GIT_AUTHOR_EMAIL:-gbrain-md-autopush@localhost}"
  git remote set-url "$remote" "$remote_url" 2>/dev/null || git remote add "$remote" "$remote_url"

  if ! git fetch "$remote" "$branch" >/dev/null 2>&1; then
    log_line "fetch failed remote=$remote branch=$branch"
    return 0
  fi

  git add -A -- .
  staged="$(git diff --cached --name-only || true)"
  if [ -n "$staged" ]; then
    if printf '%s\n' "$staged" | grep -Eiq '(^|/)(\.env($|\.)|.*secret.*|.*credential.*|.*token.*|id_(rsa|ed25519).*|.*\.(pem|key|p12|pfx)$)'; then
      git reset --quiet
      log_line "refuse: staged sensitive-looking path; reset index"
      return 0
    fi
    git commit -m "$commit_prefix $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null 2>&1 || true
  fi

  if ! git pull --rebase --autostash "$remote" "$branch" >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1 || true
    log_line "pull/rebase failed; local state preserved"
    return 0
  fi

  ahead="$(git rev-list --count "$remote/$branch..HEAD" 2>/dev/null || echo 0)"
  if [ "$ahead" != "0" ]; then
    if git push "$remote" "HEAD:$branch" >/dev/null 2>&1; then
      log_line "push ok branch=$branch head=$(git rev-parse --short HEAD)"
    else
      log_line "push failed branch=$branch head=$(git rev-parse --short HEAD)"
    fi
  else
    log_line "up-to-date branch=$branch head=$(git rev-parse --short HEAD)"
  fi
}

if [ "${1:-}" = "--once" ]; then
  run_once
  exit 0
fi

log_line "started interval=${interval}s repo=$repo remote=$remote_url branch=$branch"
while true; do
  run_once || log_line "unexpected failure"
  sleep "$interval"
done
