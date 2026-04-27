# ── Stage 1 : Machine Learning ────────────────────────────────────────────────
FROM ghcr.io/immich-app/immich-machine-learning:release-cuda AS ml-stage

# ── Image finale : Immich Server ──────────────────────────────────────────────
FROM ghcr.io/immich-app/immich-server:release

ARG PGVECTO_RS_VERSION=0.3.0

ENV DB_HOSTNAME=127.0.0.1 \
    DB_PORT=5432 \
    DB_DATABASE_NAME=immich \
    DB_USERNAME=immich \
    DB_PASSWORD=immich_db_pass \
    REDIS_HOSTNAME=127.0.0.1 \
    REDIS_PORT=6379 \
    IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003 \
    PGDATA=/data/postgres \
    ML_MODEL_CACHE=/data/model-cache \
    TZ=UTC \
    NODE_ENV=production \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH=/ml/src \
    TRANSFORMERS_CACHE=/data/model-cache

USER root

# ── Étape 1 : outils essentiels ───────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
 && rm -rf /var/lib/apt/lists/*

# ── Étape 2 : PostgreSQL + Redis + Supervisor + libgl1 ───────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql \
    redis-server \
    supervisor \
    libgl1 \
 && rm -rf /var/lib/apt/lists/*

# ── Étape 3 : pgvecto.rs ──────────────────────────────────────────────────────
RUN PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1) \
 && for PGVEC_VER in ${PGVECTO_RS_VERSION} 0.4.0 0.2.0; do \
      URL="https://github.com/tensorchord/pgvecto.rs/releases/download/v${PGVEC_VER}/vectors-pg${PG_VER}_${PGVEC_VER}_amd64.deb"; \
      if curl -fsSL --connect-timeout 30 "$URL" -o /tmp/pgvecto.deb 2>/dev/null; then \
          dpkg -i /tmp/pgvecto.deb && rm -f /tmp/pgvecto.deb \
          && echo "==> pgvecto.rs v${PGVEC_VER} installé pour pg${PG_VER}" && break; \
      fi; \
    done; \
    rm -f /tmp/pgvecto.deb

# ── Étape 4 : Machine Learning — code + venv complet depuis l'image officielle ─
# Le venv de l'image ML contient Python 3.11 + tous les packages (rapidocr, onnxruntime, etc.)
COPY --from=ml-stage /usr/src /ml/src
COPY --from=ml-stage /opt/venv /opt/venv

# ── Config supervisord ────────────────────────────────────────────────────────
COPY supervisord.conf /etc/supervisor/conf.d/immich.conf

# ── Scripts ───────────────────────────────────────────────────────────────────
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY start-server.sh      /start-server.sh
COPY start-ml.sh          /start-ml.sh
RUN chmod +x /docker-entrypoint.sh /start-server.sh /start-ml.sh

VOLUME ["/data", "/photos"]

EXPOSE 2283

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
