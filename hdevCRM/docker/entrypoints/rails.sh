#!/bin/sh

set -x

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb)
PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  sleep 2;
done

echo "Database ready to accept connections."

# Instala gems faltando no dev, onde a imagem base é a de produção.
# NUNCA em produção: se um gem não estiver na imagem, o `until bundle check`
# trava o boot em silêncio pra sempre — sem log, sem crash, sem restart.
# Fora do if, a mesma situação vira erro visível no log do container.
if [ "$RAILS_ENV" != "production" ]; then
  bundle install

  BUNDLE="bundle check"

  until $BUNDLE
  do
    sleep 2;
  done
fi

# Execute the main process of the container
exec "$@"
