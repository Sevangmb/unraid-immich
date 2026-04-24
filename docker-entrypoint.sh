#!/bin/bash
set -e

PGDATA="${PGDATA:-/data/postgres}"
ML_MODEL_CACHE="${ML_MODEL_CACHE:-/data/model-cache}"

mkdir -p "$PGDATA" "$ML_MODEL_CACHE" /photos
chown -R postgres:postgres "$PGDATA"

# ── Init PostgreSQL si premier démarrage ──────────────────────────────────────
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "==> Initialisation de PostgreSQL..."
    gosu postgres /usr/lib/postgresql/16/bin/initdb \
        -D "$PGDATA" \
        --auth-host=md5 \
        --auth-local=trust \
        -U postgres

    # pgvecto.rs doit être chargé au démarrage de postgres
    echo "shared_preload_libraries = 'vectors.so'" >> "$PGDATA/postgresql.conf"
    echo "search_path = \"\$user\", public, vectors"  >> "$PGDATA/postgresql.conf"

    # ── Démarrage temporaire pour créer user/base/extensions ─────────────────
    echo "==> Démarrage PostgreSQL (init)..."
    gosu postgres /usr/lib/postgresql/16/bin/pg_ctl -D "$PGDATA" -w start

    gosu postgres psql -U postgres <<SQL
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USERNAME}') THEN
        CREATE ROLE ${DB_USERNAME} WITH LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${DB_DATABASE_NAME} OWNER ${DB_USERNAME}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_DATABASE_NAME}')
\gexec
SQL

    gosu postgres psql -U postgres -d "${DB_DATABASE_NAME}" <<SQL
CREATE EXTENSION IF NOT EXISTS vectors;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
SQL

    gosu postgres /usr/lib/postgresql/16/bin/pg_ctl -D "$PGDATA" -w stop
    echo "==> Base de données initialisée."
fi

echo "==> Démarrage de la stack complète..."
exec "$@"
