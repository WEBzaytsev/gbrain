# WEBzaytsev GBrain

Docker Compose wrapper для GBrain: кастомный образ, Postgres/pgvector, HTTP-сервис, worker, autopilot и federation-loop.

Репозиторий хранит **инфраструктурную обвязку** и tracked brain-файлы. Runtime-состояние и база лежат отдельно и не попадают в Git.

## Структура

```text
WEBzaytsev-gbrain/
├── brain/          # пользовательские Markdown/source-файлы GBrain
├── data/           # служебное runtime-состояние GBrain: /home/gbrain, .gbrain и т. п.
├── postgres/       # данные Postgres
├── data/scripts/  # tracked helper-скрипты образа и entrypoint
├── skills/         # GBrain skillpack, копируется в runtime image
├── compose.yaml    # runtime Compose stack
├── Dockerfile      # сборка кастомного образа
└── .env.example    # шаблон переменных окружения
```

Главное правило:

- `brain/` — для пользовательских `.md` и source-файлов;
- `data/` — для служебных файлов GBrain, config/state/cache;
- `postgres/` — только для Postgres;
- `data/scripts/` — для скриптов сборки и запуска контейнера.

`brain/` монтируется в контейнер как `/home/gbrain/brain`. `data/` монтируется как `/home/gbrain`.

## Что тречится

| Путь | Git | Docker build context | Назначение |
|---|---:|---:|---|
| `brain/` | да | нет | пользовательские Markdown/source-файлы |
| `skills/` | да | да | GBrain MCP skillpack для `list_skills` / `get_skill` |
| `data/` без `data/scripts/` | нет | нет | runtime-состояние GBrain |
| `postgres/` | нет | нет | данные Postgres |
| `data/scripts/` | да | да | entrypoint/init/federation helpers |
| `.env` | нет | нет | реальные секреты и настройки |
| `.env.example` | да | да | безопасный шаблон |

Важно: всё, что кладётся в `brain/`, будет обычным содержимым репозитория, если не добавить отдельное правило в `.gitignore`.

## Сервисы

| Service | Container | Команда | Роль |
|---|---|---|---|
| `gbrain-db` | `gbrain-db` | Postgres | база данных с pgvector |
| `gbrain-init` | `gbrain-init` | `init` | первичная настройка GBrain и регистрация local sources |
| `gbrain` | `gbrain` | default `serve` | HTTP API/admin UI |
| `gbrain-worker` | `gbrain-worker` | `worker` | обработка jobs |
| `gbrain-autopilot` | `gbrain-autopilot` | `autopilot` | периодическая работа с `/home/gbrain/brain` |
| `gbrain-federation` | `gbrain-federation` | `federation` | выдаёт OAuth-клиентам доступ ко всем sources |

Образ для GBrain-сервисов:

```text
hub.zaitsv.dev/gbrain:${IMAGE_TAG:-latest}
```

Postgres:

```text
pgvector/pgvector:pg16
```

## Быстрый старт

```bash
git clone https://github.com/WEBzaytsev/gbrain.git
cd gbrain

cp .env.example .env
chmod 600 .env
mkdir -p brain data postgres
```

Дальше отредактировать `.env`:

- заменить `GBRAIN_POSTGRES_PASSWORD`;
- заменить `GBRAIN_ADMIN_BOOTSTRAP_TOKEN`;
- выставить `GBRAIN_PUBLIC_URL`;
- выставить `GBRAIN_HTTP_CORS_ORIGIN`;
- добавить LLM/embedding credentials, если нужен полноценный retain/query flow.

Запуск:

```bash
docker compose --env-file .env up -d --wait
```

Проверка:

```bash
docker compose --env-file .env ps
curl -fsS http://127.0.0.1:${GBRAIN_PORT:-3131}/health
```

По умолчанию HTTP-порт публикуется только на localhost:

```yaml
127.0.0.1:${GBRAIN_PORT:-3131}:${GBRAIN_PORT:-3131}
```

Публичный доступ обычно делается через внешний reverse proxy.

## Пользовательские файлы

Класть Markdown/source-файлы сюда:

```text
brain/
```

Примеры:

```text
brain/projects/
brain/notes/
brain/inbox/
```

При `gbrain-init` каждая не скрытая подпапка первого уровня в `/home/gbrain/brain` регистрируется как local source:

```text
brain/projects/ -> source id: projects
brain/notes/    -> source id: notes
brain/inbox/    -> source id: inbox
```

Скрытые директории вида `.something/` пропускаются.

Если файлы копируются на сервер вручную, проверьте владельца:

```bash
chown -R 10001:10001 brain data
```

`10001` — пользователь `gbrain` внутри контейнера.

## Переменные окружения

Основные переменные берутся из `.env`.

### Runtime

| Переменная | Назначение |
|---|---|
| `IMAGE_TAG` | необязательный tag образа, default `latest` |
| `GBRAIN_PORT` | HTTP-порт, default `3131` |
| `GBRAIN_BIND` | bind address внутри контейнера, default `0.0.0.0` |
| `GBRAIN_PUBLIC_URL` | публичный URL сервиса |
| `GBRAIN_HTTP_CORS_ORIGIN` | CORS origin для браузерного клиента |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | bootstrap-токен админки |
| `GBRAIN_TOKEN_TTL` | TTL токенов, default `3600` |

### Database

| Переменная | Назначение |
|---|---|
| `GBRAIN_POSTGRES_USER` | Postgres user |
| `GBRAIN_POSTGRES_PASSWORD` | Postgres password |
| `GBRAIN_POSTGRES_DB` | Postgres database |
| `GBRAIN_DATABASE_URL` | DSN для GBrain-сервисов |

### Models/providers

| Переменная | Назначение |
|---|---|
| `GBRAIN_OPENAI_API_KEY` | OpenAI/OpenAI-compatible API key |
| `GBRAIN_OPENAI_BASE_URL` | OpenAI-compatible endpoint, указывать с `/v1` |
| `GBRAIN_CHAT_MODEL` | chat model override |
| `GBRAIN_EXPANSION_MODEL` | expansion model override |
| `GBRAIN_ANTHROPIC_API_KEY` | Anthropic key |
| `GBRAIN_VOYAGE_API_KEY` | Voyage key |
| `GBRAIN_ZEROENTROPY_API_KEY` | ZeroEntropy key |

### Init/embedding

| Переменная | Назначение |
|---|---|
| `GBRAIN_SCHEMA_PACK` | schema pack, default `gbrain-base-v2` |
| `GBRAIN_INIT_NO_EMBEDDING` | `1` для smoke без embeddings |
| `GBRAIN_INIT_EMBEDDING_MODEL` | embedding model |
| `GBRAIN_INIT_EMBEDDING_DIMENSIONS` | optional custom dimensions |
| `GBRAIN_INIT_SKIP_EMBED_CHECK` | `1`, чтобы пропустить embedding check |

### Background services

| Переменная | Назначение |
|---|---|
| `GBRAIN_WORKER_QUEUE` | worker queue, default `default` |
| `GBRAIN_WORKER_CONCURRENCY` | worker concurrency, default `2` |
| `GBRAIN_WORKER_MAX_RSS_MB` | worker memory guard, `0` выключает лимит |
| `GBRAIN_REPO` | путь к markdown repo внутри контейнера, default `/home/gbrain/brain` |
| `GBRAIN_AUTOPILOT_INTERVAL` | autopilot interval, seconds |
| `GBRAIN_FEDERATION_INTERVAL` | federation sync interval, seconds |
| `GBRAIN_DURABILITY_SOURCE` | source id для native harden, default `default` |
| `GBRAIN_DURABILITY_BRANCH` | Git branch для native harden, default `main` |
| `GBRAIN_DURABILITY_INSTALL_CRON` | `0` в Docker: crontab внутри one-shot контейнера не является durable scheduler |
| `GBRAIN_GITHUB_PAT` | PAT для `gbrain sources harden`; хранить только в `.env` / secret env |

## Init flow

`gbrain-init` делает три шага:

1. ждёт Postgres;
2. запускает `gbrain init`, если `/home/gbrain/.gbrain/config.json` ещё нет;
3. регистрирует подпапки из `/home/gbrain/brain` как federated local sources.

Повторный запуск безопасен: если config уже есть, init пропускается, но source registration всё равно проверяется.

Запустить init отдельно:

```bash
docker compose --env-file .env up gbrain-init
```

## Native Git durability / auto-push

В GBrain уже есть родной механизм публикации brain repo: `gbrain sources harden`. Отдельный `git push` sidecar не нужен.

Для текущего Docker layout используется one-shot command `harden`: он сначала привязывает `default` source к mounted repo, затем запускает native `gbrain sources harden`. PAT задаётся через `.env` / environment, не через CLI argument:

```bash
docker compose --env-file .env run --rm gbrain harden
```

Если `GBRAIN_GITHUB_PAT` пустой, команда только привяжет source и завершится с кодом `2`, не оставляя credential wiring наполовину.

Что ставит GBrain: repo-local credential wiring, локальный untracked `post-commit` hook, committed `scripts/brain-commit-push.sh`, durability rules в `AGENTS.md`/`RESOLVER.md`, 30-минутный DB-free pull cron и push-probe.

Для проверки без вывода секрета:

```bash
docker compose --env-file .env exec -T gbrain \
  gbrain sources list --json

test -x brain/scripts/brain-commit-push.sh
test -x brain/.git/hooks/post-commit
```

`GBRAIN_GITHUB_PAT` хранить только в реальном `.env` или внешнем secret env; не коммитить и не вставлять в URL remote.

## Управление stack

Старт:

```bash
docker compose --env-file .env up -d --wait
```

Пересоздать GBrain-сервисы без Postgres:

```bash
docker compose --env-file .env up -d --no-deps --force-recreate --wait \
  gbrain gbrain-worker gbrain-autopilot gbrain-federation
```

Остановить:

```bash
docker compose --env-file .env down
```

Логи:

```bash
docker compose --env-file .env logs -f gbrain
```

Статус:

```bash
docker compose --env-file .env ps
```

## Admin UI

HTTP-сервис отдаёт admin UI через `gbrain serve --http`.

Полезные проверки:

```bash
curl -fsS http://127.0.0.1:${GBRAIN_PORT:-3131}/health
curl -I http://127.0.0.1:${GBRAIN_PORT:-3131}/admin
curl -I http://127.0.0.1:${GBRAIN_PORT:-3131}/admin/login
```

`GBRAIN_ADMIN_BOOTSTRAP_TOKEN` хранить только в реальном `.env`.

## Сборка образа

Локальная сборка:

```bash
docker build \
  --build-arg GBRAIN_REF=f72de97943eb9dc1292a80f85d19db7e311855dc \
  --build-arg GIT_COMMIT_SHA="$(git rev-parse HEAD)" \
  -t hub.zaitsv.dev/gbrain:latest \
  .
```

Dockerfile:

- ставит `gbrain` через Bun из `github:garrytan/gbrain`;
- копирует tracked `skills/` в `/usr/local/share/gbrain/skills`;
- задаёт `GBRAIN_SKILLS_DIR=/usr/local/share/gbrain/skills`, чтобы MCP `list_skills` / `get_skill` работали из `hub.zaitsv.dev/gbrain` без ручной настройки;
- применяет patch admin UI из `data/scripts/patch-gbrain-admin-ui.py`;
- создаёт пользователя `gbrain` с UID `10001`;
- копирует entrypoint/init/federation/durability scripts из `data/scripts/`;
- работает из `/home/gbrain/brain`.

`brain/`, runtime-файлы из `data/`, `postgres/`, `.env` и backup-файлы исключены из Docker build context. В build context оставлены только tracked helper-файлы `data/scripts/**`.

## CI

Woodpecker pipeline build-only:

- собирает `linux/amd64` image;
- пушит `hub.zaitsv.dev/gbrain:latest`;
- ставит OCI label `org.opencontainers.image.revision=${CI_COMMIT_SHA}`;
- использует registry cache `hub.zaitsv.dev/gbrain:buildcache`.

Pipeline запускается на `push` в `main/master`, если менялись:

- `Dockerfile`;
- `compose.yaml`;
- `skills/**`;
- `data/scripts/**`;
- `.dockerignore`;
- `README.md`;
- `.woodpecker/gbrain.yml`.

## Проверки перед push

```bash
bash -n data/scripts/entrypoint.sh data/scripts/init.sh data/scripts/grant-federation.sh
python3 -m py_compile data/scripts/patch-gbrain-admin-ui.py
docker compose --env-file .env.example config --quiet
test -f skills/RESOLVER.md
find skills -name SKILL.md | grep -q .
```

Проверить, что Compose рендерит нужные mounts:

```bash
docker compose --env-file .env.example config | grep -E 'source: .*/(brain|data|postgres)|target: /home/gbrain|target: /home/gbrain/brain|target: /var/lib/postgresql/data'
```

## Безопасность

- Не коммитить `.env`.
- Не писать реальные ключи/токены в README, issue, PR или logs.
- Хранить `.env` с mode `600`.
- Оставлять внешний доступ к GBrain за reverse proxy/auth layer.
- Не класть служебные runtime-файлы в `brain/`.
- Не класть пользовательские Markdown/source-файлы в `data/`.

## Backup

Минимальный backup state перед рискованными действиями:

```bash
mkdir -p backups
BACKUP="backups/gbrain-$(date +%Y%m%d-%H%M%S).tgz"
tar -czf "$BACKUP" .env brain data postgres
chmod 600 "$BACKUP"
```

Перед удалением любого state-файла или директории сначала сделать backup соответствующего объекта.
