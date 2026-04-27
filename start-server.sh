#!/bin/bash
# Ajoute le bin PostgreSQL au PATH pour pg_isready
PG_VER=$(ls /usr/lib/postgresql/ | sort -V | tail -1)
export PATH="/usr/lib/postgresql/$PG_VER/bin:$PATH"

until pg_isready -h 127.0.0.1 -U "${DB_USERNAME}" 2>/dev/null; do
    sleep 1
done

until redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -q PONG; do
    sleep 1
done

# Détecte le chemin du serveur Immich (varie selon la version de l'image)
for SERVER_DIR in /usr/src/app /usr/src/app/server /app; do
    if [ -f "$SERVER_DIR/bin/start.sh" ]; then
        cd "$SERVER_DIR"
        exec /bin/bash bin/start.sh
    fi
done

echo "ERREUR : script de démarrage Immich introuvable dans /usr/src/app, /usr/src/app/server, /app"
exit 1
