#!/bin/bash
# Ajoute le bin PostgreSQL au PATH pour pg_isready
PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
export PATH="/usr/lib/postgresql/$PG_VER/bin:$PATH"

until pg_isready -h 127.0.0.1 2>/dev/null; do
    sleep 1
done

until redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -q PONG; do
    sleep 1
done

# Assure que le rôle, la base et les extensions existent (idempotent — gère les PGDATA existants)
psql -U postgres 2>/dev/null <<SQL || true
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${DB_USERNAME}') THEN
        CREATE ROLE "${DB_USERNAME}" WITH LOGIN PASSWORD '${DB_PASSWORD}';
    END IF;
END
\$\$;
SELECT 'CREATE DATABASE "${DB_DATABASE_NAME}" OWNER "${DB_USERNAME}"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${DB_DATABASE_NAME}')
\gexec
GRANT ALL PRIVILEGES ON DATABASE "${DB_DATABASE_NAME}" TO "${DB_USERNAME}";
SQL

psql -U postgres -d "${DB_DATABASE_NAME}" 2>/dev/null <<SQL || true
CREATE EXTENSION IF NOT EXISTS vector;
DO \$\$ BEGIN
  CREATE EXTENSION IF NOT EXISTS vectors;
EXCEPTION WHEN OTHERS THEN NULL;
END \$\$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS cube;
CREATE EXTENSION IF NOT EXISTS earthdistance;
SQL

# Détecte le chemin du serveur Immich (varie selon la version de l'image)
for SERVER_DIR in /usr/src/app /usr/src/app/server /app; do
    if [ -f "$SERVER_DIR/bin/start.sh" ]; then
        cd "$SERVER_DIR"
        exec /bin/bash bin/start.sh
    fi
done

echo "ERREUR : script de démarrage Immich introuvable dans /usr/src/app, /usr/src/app/server, /app"
exit 1
