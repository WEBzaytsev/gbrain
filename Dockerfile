# syntax=docker/dockerfile:1

FROM oven/bun:1.3.10 AS bun

FROM node:22-bookworm AS gbrain-build

ARG GBRAIN_REF=eefe8b5741c27e59bf65198d46e3dfe5bfa70ce9

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

ENV BUN_INSTALL=/usr/local
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY data/scripts/patch-gbrain-admin-ui.py /tmp/patch-gbrain-admin-ui.py

RUN bun install -g "github:garrytan/gbrain#${GBRAIN_REF}" \
 && python3 /tmp/patch-gbrain-admin-ui.py \
 && gbrain --version

FROM debian:bookworm-slim

ARG GIT_COMMIT_SHA=unknown

COPY --from=gbrain-build /usr/local /usr/local

ENV BUN_INSTALL=/usr/local
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GIT_COMMIT_SHA=${GIT_COMMIT_SHA}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      gosu \
      openssh-client \
      postgresql-client \
 && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin gbrain
ENV HOME=/home/gbrain

RUN mkdir -p /home/gbrain/.gbrain /home/gbrain/brain \
 && chown -R gbrain:gbrain /home/gbrain

VOLUME ["/home/gbrain"]

COPY --chmod=755 data/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 data/scripts/init.sh /usr/local/bin/init.sh
COPY --chmod=755 data/scripts/grant-federation.sh /usr/local/bin/grant-federation.sh

WORKDIR /home/gbrain/brain

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
