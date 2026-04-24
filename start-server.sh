#!/bin/bash
# Attend que PostgreSQL et Redis soient prêts avant de démarrer Immich

until pg_isready -h 127.0.0.1 -U "${DB_USERNAME}" 2>/dev/null; do
    sleep 1
done

until redis-cli -h 127.0.0.1 ping 2>/dev/null | grep -q PONG; do
    sleep 1
done

cd /usr/src/app/server
exec /bin/bash bin/start.sh
