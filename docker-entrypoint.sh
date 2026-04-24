#!/bin/bash
set -e

PGDATA="${PGDATA:-/data/postgres}"
ML_MODEL_CACHE="${ML_MODEL_CACHE:-/data/model-cache}"

# Détecte la version PostgreSQL installée
PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
PGBIN="/usr/lib/postgresql/$PG_VER/bin"

mkdir -p "$PGDATA" "$ML_MODEL_CACHE" /photos
chown -R postgres:postgres "$PGDATA"

# ── Init PostgreSQL si premier démarrage ──────────────────────────────────────
if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "==> Initialisation de PostgreSQL $PG_VER..."
    gosu postgres "$PGBIN/initdb" \
        -D "$PGDATA" \
        --auth-host=md5 \
        --auth-local=trust \
        -U postgres

    # Charge pgvecto.rs uniquement si vectors.so est présent
    if ls "/usr/lib/postgresql/$PG_VER/lib/vectors.so" 2>/dev/null; then
        cat >> "$PGDATA/postgresql.conf" << 'PGCONF'
shared_preload_libraries = 'vectors.so'
search_path = "$user", public, vectors
PGCONF
        echo "==> pgvecto.rs activé dans postgresql.conf"
    fi

    echo "==> Démarrage PostgreSQL (init)..."
    gosu postgres "$PGBIN/pg_ctl" -D "$PGDATA" -w start

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

    # Extensions : tente pgvecto.rs, repli sur pgvector
    gosu postgres psql -U postgres -d "${DB_DATABASE_NAME}" <<SQL
DO \$\$ BEGIN
  CREATE EXTENSION IF NOT EXISTS vectors;
EXCEPTION WHEN OTHERS THEN
  BEGIN
    CREATE EXTENSION IF NOT EXISTS vector;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END \$\$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
SQL

    gosu postgres "$PGBIN/pg_ctl" -D "$PGDATA" -w stop
    echo "==> Base de données initialisée."
fi

echo "==> Démarrage de la stack complète..."
exec "$@"
