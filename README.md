# WEBzaytsev/gbrain

Runtime wrapper for running GBrain from the published image:

```yaml
image: hub.zaitsv.dev/gbrain:${IMAGE_TAG:-latest}
```

This repository is a deployment scaffold. Image build details live in `Dockerfile` and Woodpecker; `compose.yaml` is for runtime only.

## What this stack runs

| Service | Purpose | Runtime mode |
|---|---|---|
| `gbrain-db` | PostgreSQL + pgvector | `pgvector/pgvector:pg16` |
| `gbrain-init` | Initializes GBrain database/config/source state | `command: init` |
| `gbrain` | Main HTTP/MCP server | default image entrypoint, no Compose `command` |
| `gbrain-worker` | Background Minions/job worker | `command: worker` |
| `gbrain-autopilot` | Periodic source sync / autopilot loop | `command: autopilot` |
| `gbrain-federation` | Periodic federation grant maintenance | `command: federation` |

`gbrain-federation` is a normal Compose service. If a deployment does not need it, remove that service from `compose.yaml` rather than hiding it behind a Compose profile.

## Runtime layout

Host paths:

| Host path | Container path | Owner |
|---|---|---|
| `./data` | `/home/gbrain` | GBrain app state, config, local brain repo |
| `./postgres` | `/var/lib/postgresql/data` | PostgreSQL data |

Inside the GBrain container:

```text
HOME=/home/gbrain
/home/gbrain/.gbrain
/home/gbrain/brain
```

PostgreSQL has an explicit shared-memory setting:

```yaml
shm_size: 1g
```

`scripts/db-init.sql` is tracked as a support/reference SQL file. It is not mounted into `/docker-entrypoint-initdb.d`; app-level setup is handled by `gbrain-init`.

## Prerequisites

- Docker with the Compose plugin.
- Access to `hub.zaitsv.dev/gbrain`.
- A real ignored `.env` file based on `.env.example`.
- API keys for the providers you actually use.

The real `.env` must stay untracked. Do not commit secrets.

## Configure

Create a local env file:

```bash
cp .env.example .env
chmod 600 .env
```

Edit `.env` and replace placeholder values:

```env
GBRAIN_POSTGRES_PASSWORD=replace-with-long-random-password
GBRAIN_DATABASE_URL=postgresql://gbrain:replace-with-long-random-password@gbrain-db:5432/gbrain
GBRAIN_PUBLIC_URL=https://gbrain.example.com
GBRAIN_HTTP_CORS_ORIGIN=https://gbrain.example.com
GBRAIN_ADMIN_BOOTSTRAP_TOKEN=replace-with-random-token-at-least-32-chars
```

Provider keys are optional for structural smoke tests, but required for a useful embedding/LLM-enabled brain:

```env
OPENAI_API_KEY=
OPENAI_BASE_URL=
GBRAIN_CHAT_MODEL=
GBRAIN_EXPANSION_MODEL=
ANTHROPIC_API_KEY=
VOYAGE_API_KEY=
ZEROENTROPY_API_KEY=
```

## Custom OpenAI-compatible endpoint

For an OpenAI-compatible endpoint, set the endpoint URL, token, and GBrain model ids in `.env`.

Example for `https://tokenly.plus/api/v1`:

```env
OPENAI_API_KEY=replace-with-tokenly-token
OPENAI_BASE_URL=https://tokenly.plus/api/v1
GBRAIN_CHAT_MODEL=openai:<chat-model-id-supported-by-tokenly>
GBRAIN_EXPANSION_MODEL=openai:<small-chat-model-id-supported-by-tokenly>
```

The base URL must include the OpenAI-compatible `/v1` suffix when the provider serves routes there.

If the same endpoint also supports embeddings and this is a fresh brain, configure init before the first `gbrain-init` run:

```env
GBRAIN_INIT_EMBEDDING_MODEL=openai/<embedding-model-id-supported-by-tokenly>
```

Do not set `GBRAIN_INIT_EMBEDDING_DIMENSIONS` for the normal OpenAI-style path. Set it only for a provider/model that explicitly requires a custom dimension.

If the endpoint is chat-only, do not route embeddings to it. Keep embeddings on a provider that supports `/embeddings`, or run a structural smoke test with:

```env
GBRAIN_INIT_NO_EMBEDDING=1
```

After changing endpoint/model variables, recreate the services that need them:

```bash
docker compose --env-file .env up -d --force-recreate \
  gbrain gbrain-worker gbrain-autopilot gbrain-federation
```

For a fresh brain where embedding init variables changed before first initialization, rerun the init service too:

```bash
docker compose --env-file .env up gbrain-init
```

For a no-spend structural initialization check, use:

```env
GBRAIN_INIT_NO_EMBEDDING=1
```

## Start

Validate the rendered Compose config first:

```bash
docker compose --env-file .env config --quiet
```

Pull images and start the stack:

```bash
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

Check service state:

```bash
docker compose --env-file .env ps
```

Check the HTTP health endpoint:

```bash
curl -fsS "http://127.0.0.1:${GBRAIN_PORT:-3131}/health"
```

Open the main service logs when needed:

```bash
docker compose --env-file .env logs -f gbrain
```

## Common operations

Run the init service again after changing init-related settings:

```bash
docker compose --env-file .env up gbrain-init
```

Restart only the main server:

```bash
docker compose --env-file .env up -d --no-deps --force-recreate gbrain
```

Restart background services:

```bash
docker compose --env-file .env up -d --no-deps --force-recreate \
  gbrain-worker gbrain-autopilot gbrain-federation
```

Inspect the rendered service contract:

```bash
docker compose --env-file .env config
```

Stop the stack without deleting data:

```bash
docker compose --env-file .env down
```

## Image build

`compose.yaml` does not build images. Build configuration belongs to:

- `Dockerfile`
- `.woodpecker/gbrain.yml`

Every Dockerfile in this repo must start with an explicit BuildKit syntax directive:

```dockerfile
# syntax=docker/dockerfile:1
```

The runtime Compose image stays literal:

```yaml
image: hub.zaitsv.dev/gbrain:${IMAGE_TAG:-latest}
```

Only the tag is configurable through `IMAGE_TAG`.

## Runtime contract checks

Before pushing Compose/runtime changes, verify:

```bash
bash -n scripts/entrypoint.sh scripts/init.sh scripts/grant-federation.sh
docker compose --env-file .env.example config --quiet
docker compose --env-file .env.example config --format json >/tmp/gbrain-compose.json
```

The intended source shape:

- main service is named `gbrain`;
- `gbrain` has no Compose `command`;
- `gbrain-init` uses `command: init`;
- `gbrain-worker` uses `command: worker`;
- `gbrain-autopilot` uses `command: autopilot`;
- `gbrain-federation` uses `command: federation`;
- no Compose `profiles` are used;
- no Compose-level `entrypoint` is used;
- no runtime `build:` or `context:` section is used;
- no full-image override variable is used;
- no role-switching environment variable is used;
- no required-error interpolation is used for runtime environment variables;
- runtime fallbacks use inline defaults like `${VAR:-value}` or optional-empty defaults like `${VAR:-}`;
- app data is mounted as `./data:/home/gbrain`;
- PostgreSQL data is mounted as `./postgres:/var/lib/postgresql/data`;
- the main healthcheck uses `curl -fsS` against `/health`.

Source scans should confirm that legacy service names, profile-gated federation, role-switching environment variables, full-image overrides, runtime build sections, host-path override comments, and required-error interpolation are absent from the current runtime contract.
