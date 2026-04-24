# ── Stage 1 : Machine Learning (Python + packages CUDA) ──────────────────────
FROM ghcr.io/immich-app/immich-machine-learning:release-cuda AS ml-stage

# ── Image finale : Immich Server + PostgreSQL + Redis + ML ───────────────────
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

# ── CA certs + outils de base ─────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
 && rm -rf /var/lib/apt/lists/*

# ── PostgreSQL 16 via PGDG ───────────────────────────────────────────────────
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg \
 && echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update && apt-get install -y --no-install-recommends \
    postgresql-16 \
    redis-server \
    supervisor \
    gosu \
    python3.11 \
    python3.11-dev \
 && ln -sf /usr/bin/python3.11 /usr/local/bin/python3.11 \
 && rm -rf /var/lib/apt/lists/*

# ── pgvecto.rs : extension PostgreSQL pour la recherche vectorielle ───────────
RUN curl -fsSL \
    "https://github.com/tensorchord/pgvecto.rs/releases/download/v${PGVECTO_RS_VERSION}/vectors-pg16_${PGVECTO_RS_VERSION}_amd64.deb" \
    -o /tmp/pgvecto.deb \
 && dpkg -i /tmp/pgvecto.deb \
 && rm /tmp/pgvecto.deb

# ── Machine Learning : venv (packages pré-compilés) + code app ───────────────
COPY --from=ml-stage /opt/venv  /opt/venv
COPY --from=ml-stage /usr/src   /ml/src

# ── Supervisord config ────────────────────────────────────────────────────────
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
