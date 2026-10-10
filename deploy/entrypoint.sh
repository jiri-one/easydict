#!/bin/sh
# Container start: bring the database schema up to date and refresh the static files
# (served by the reverse proxy from a shared volume), then run the server command.
set -e
python manage.py migrate --noinput
python manage.py collectstatic --noinput --verbosity 0
exec "$@"
