# WEBzaytsev GBrain Docker Compose

Private Docker Compose scaffold for running [garrytan/gbrain](https://github.com/garrytan/gbrain) as a Postgres-backed HTTP MCP service.

This repository intentionally **does not publish or deploy a Docker image**. The image is built locally from the pinned `GBRAIN_REF` when `docker compose build` runs.

Runtime state uses local bind mounts, not anonymous/named Compose volumes:

| Host path | Container path | Purpose |
|---|---|---|
| `./data/postgres` | `/var/lib/postgresql/data` | Postgres/pgvector data |
| `./data/gbrain-home` | `/home/gbrain/.gbrain` | GBrain config/cache/state |
| `./brain-repo` | `/data/brain` | Markdown source directories |

The GBrain image also declares `VOLUME ["/home/gbrain/.gbrain", "/data/brain"]` so the durable directories are explicit at image level as well as in Compose.

## Shape

| Service | Role | Expected steady state |
|---|---|---|
| `gbrain-db` | Postgres 16 + pgvector | running / healthy |
| `gbrain-init` | one-shot DB/config/source bootstrap | `Exited(0)` after success |
| `gbrain-serve` | HTTP MCP server: `/mcp`, `/admin`, `/health` | running / healthy |
| `gbrain-worker` | durable background jobs worker | running |
| `gbrain-autopilot` | periodic sync/enrichment dispatcher | running |
| `gbrain-federation` | optional grant-all-sources-to-all-OAuth-clients loop | disabled by default (`federation` profile) |

## Quick start

```bash
cp .env.example .env
chmod 600 .env
# edit .env: set real GBRAIN_POSTGRES_PASSWORD, GBRAIN_DATABASE_URL, GBRAIN_PUBLIC_URL,
# GBRAIN_ADMIN_BOOTSTRAP_TOKEN, and provider keys.

docker compose --env-file .env config --quiet
docker compose --env-file .env build
docker compose --env-file .env up -d
```

The entrypoints create/chown the GBrain bind mounts for the internal `gbrain` user. The Postgres image manages permissions for `./data/postgres`.

Verify:

```bash
docker compose --env-file .env ps
curl -fsS "$GBRAIN_PUBLIC_URL/health"
docker compose --env-file .env exec gbrain-serve gbrain doctor
```

`gbrain-init` is a one-shot container. A healthy deployed stack should normally show it as `Exited (0)`.

## Federation is off by default

`gbrain-federation` periodically updates every OAuth client so it can read every source. That is useful only for a fully shared team brain. It disables per-client source separation, so this repo keeps it behind an explicit profile:

```bash
docker compose --env-file .env --profile federation up -d gbrain-federation
```

Do not enable it for personal/multi-tenant deployments where clients should have different source access.

## Local source directories

Put local markdown sources under `brain-repo/<source-id>/`. During `gbrain-init`, every direct subdirectory is registered as a federated local path source.

```text
brain-repo/
  docs/
    README.md
  meetings/
    2026-07-19.md
```

For GitHub-backed sources that should auto-pull, register them through GBrain itself after the stack is up:

```bash
docker compose --env-file .env exec gbrain-serve \
  gbrain sources add docs --url https://github.com/ORG/REPO.git --name Docs --federated

docker compose --env-file .env exec gbrain-serve gbrain sync --source docs
```

## No secrets in git

- Real `.env` files are ignored.
- `brain-repo/`, `data/`, `backups/`, dumps, archives are ignored.
- `.env.example` contains placeholders only.

## Updating GBrain

1. Check upstream ref:
   ```bash
   git ls-remote https://github.com/garrytan/gbrain.git refs/heads/master
   ```
2. Update `GBRAIN_REF` in `.env.example` and docs if desired.
3. Rebuild locally:
   ```bash
   docker compose --env-file .env build --no-cache
   ```
4. Do not push a built image unless a separate registry/deploy task explicitly asks for it.
