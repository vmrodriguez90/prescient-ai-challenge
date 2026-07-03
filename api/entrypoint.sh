#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h db -U prescient; do
  sleep 1
done
echo "PostgreSQL is ready."

mkdir -p tmp/pids log
rm -f tmp/pids/server.pid

echo "Running migrations..."
bundle exec rails db:prepare

echo "Seeding database..."
bundle exec rails db:seed

echo "Starting cron daemon..."
cron

echo "Starting Rails server..."
exec "$@"
