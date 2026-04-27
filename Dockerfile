# ── Stage 1 : Machine Learning ────────────────────────────────────────────────
FROM ghcr.io/immich-app/immich-machine-learning:release-cuda AS ml-stage

# ── Image finale : Immich Server (base Trixie) ────────────────────────────────
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

# ── Étape 1 : outils essentiels (ca-certs en premier pour les téléchargements) ─
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gosu \
 && rm -rf /var/lib/apt/lists/*

# ── Étape 2 : PostgreSQL (version auto depuis les repos Debian) ───────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql \
    redis-server \
    supervisor \
    python3 \
    python3-venv \
    python3-dev \
    build-essential \
    libgl1 \
 && rm -rf /var/lib/apt/lists/*

# ── Étape 3 : pgvecto.rs (détecte la version PG installée) ───────────────────
RUN PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1) \
 && echo "==> PostgreSQL détecté : $PG_VER" \
 && for PGVEC_VER in ${PGVECTO_RS_VERSION} 0.4.0 0.2.0; do \
      URL="https://github.com/tensorchord/pgvecto.rs/releases/download/v${PGVEC_VER}/vectors-pg${PG_VER}_${PGVEC_VER}_amd64.deb"; \
      echo "Tentative pgvecto.rs v${PGVEC_VER} pour pg${PG_VER}..."; \
      if curl -fsSL --connect-timeout 30 "$URL" -o /tmp/pgvecto.deb 2>/dev/null; then \
          dpkg -i /tmp/pgvecto.deb && rm -f /tmp/pgvecto.deb \
          && echo "==> pgvecto.rs v${PGVEC_VER} installé pour pg${PG_VER}" && break; \
      fi; \
    done; \
    rm -f /tmp/pgvecto.deb; \
    echo "==> pgvecto.rs terminé"

# ── Étape 4 : Machine Learning — code source + venv frais ────────────────────
COPY --from=ml-stage /usr/src /ml/src

# Venv frais + toutes les dépendances ML (liste explicite depuis pyproject.toml)
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir --upgrade pip

# Installe le package immich-ml depuis sa source si pyproject.toml présent
RUN cd /ml/src && /opt/venv/bin/pip install --no-cache-dir --no-deps -e . 2>/dev/null || true

RUN /opt/venv/bin/pip install --no-cache-dir \
    aiocache \
    fastapi \
    gunicorn \
    huggingface-hub \
    insightface \
    numpy \
    "opencv-python-headless" \
    orjson \
    pillow \
    "pydantic>=2" \
    pydantic-settings \
    python-multipart \
    rich \
    tokenizers \
    "uvicorn[standard]"

RUN /opt/venv/bin/pip install --no-cache-dir "rapidocr-general-cpu" || true

RUN /opt/venv/bin/pip install --no-cache-dir "onnxruntime-gpu" \
 || /opt/venv/bin/pip install --no-cache-dir "onnxruntime"

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
