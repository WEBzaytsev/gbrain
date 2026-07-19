FROM oven/bun:1.3.10

ARG GBRAIN_REF=eefe8b5741c27e59bf65198d46e3dfe5bfa70ce9

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates git gosu postgresql-client tini \
 && rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/usr/local
ENV PATH=/usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN bun install -g "github:garrytan/gbrain#${GBRAIN_REF}" \
 && gbrain --version

RUN useradd --create-home --uid 10001 --shell /usr/sbin/nologin gbrain
ENV HOME=/home/gbrain
ENV GBRAIN_HOME=/home/gbrain/.gbrain

RUN mkdir -p /data/brain /home/gbrain/.gbrain \
 && chown -R gbrain:gbrain /data /home/gbrain

VOLUME ["/home/gbrain/.gbrain", "/data/brain"]

COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/init.sh /usr/local/bin/init.sh
COPY --chmod=755 scripts/grant-federation.sh /usr/local/bin/grant-federation.sh

WORKDIR /data/brain

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
