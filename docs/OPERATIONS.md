# Operations

## Bring up

```bash
cp .env.example .env
chmod 600 .env
# edit .env

docker compose --env-file .env config --quiet
docker compose --env-file .env build
docker compose --env-file .env up -d
```

## Expected states

```text
gbrain-db         running healthy
gbrain-init       exited 0
gbrain-serve      running healthy
gbrain-worker     running
gbrain-autopilot  running
gbrain-federation absent unless --profile federation is enabled
```

## Bind mounts

This stack uses local bind mounts instead of named Compose volumes:

```text
./data/postgres     -> /var/lib/postgresql/data
./data/gbrain-home  -> /home/gbrain/.gbrain
./brain-repo        -> /data/brain
```

The GBrain Dockerfile declares `VOLUME ["/home/gbrain/.gbrain", "/data/brain"]`. Its entrypoints chown the GBrain bind mounts to the internal `gbrain` user before dropping privileges. Postgres handles `./data/postgres` through its official image entrypoint.

## Useful commands

```bash
docker compose --env-file .env ps
docker compose --env-file .env logs -f gbrain-serve
docker compose --env-file .env exec gbrain-serve gbrain doctor
docker compose --env-file .env exec gbrain-serve gbrain sources list
docker compose --env-file .env exec gbrain-serve gbrain query "question" --source-id __all__
```

## Re-run init

`gbrain-init` skips `gbrain init` if `/home/gbrain/.gbrain/config.json` already exists. It still attempts idempotent registration of subdirectories under `/data/brain`.

```bash
docker compose --env-file .env up gbrain-init
```

## Enable federation explicitly

Federation grants all OAuth clients read access to all sources every `GBRAIN_FEDERATION_INTERVAL` seconds.

```bash
docker compose --env-file .env --profile federation up -d gbrain-federation
```

Disable:

```bash
docker compose --env-file .env --profile federation stop gbrain-federation
docker compose --env-file .env --profile federation rm -f gbrain-federation
```

## Backup

```bash
mkdir -p backups
docker compose --env-file .env exec -T gbrain-db \
  pg_dump -U "$GBRAIN_POSTGRES_USER" "$GBRAIN_POSTGRES_DB" > "backups/gbrain-$(date +%F).sql"
```

Keep backup files out of git.
