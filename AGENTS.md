# Agent instructions for WEBzaytsev/gbrain

This repository is a Docker Compose wrapper around upstream `garrytan/gbrain`.

Rules:

- Do not commit real `.env`, provider keys, GitHub tokens, dumps, DB volumes, or `brain-repo/` content.
- Do not publish or deploy Docker images from this repo unless the operator explicitly asks for a registry/deploy task.
- Keep `gbrain-init` as a one-shot bootstrap service that exits `0` on success.
- Keep long-running services separate: `gbrain-serve`, `gbrain-worker`, `gbrain-autopilot`.
- Keep `gbrain-federation` optional. It grants every OAuth client read access to every source.
- Prefer pinned upstream GBrain refs (`GBRAIN_REF`) over floating `master` for reproducibility.
- Validate with `docker compose --env-file .env.example config --quiet`, shell syntax checks, and a staged secret scan before pushing.
