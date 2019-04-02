#!/bin/bash
set -e

# get or set database info
export POSTGRES_HOST="${POSTGRES_HOST:-postgis}"
export POSTGRES_DBNAME="${POSTGRES_DBNAME:-gis}"
export POSTGRES_USER="${POSTGRES_USER:-docker}"
export POSTGRES_PASS="${POSTGRES_PASS:-docker}"

# declare some paths
CARTO_DIR="/var/www/src/openstreetmap-carto"
DATA_DIR="/var/www/data"

# add postgres creds to user homedir
echo "${POSTGRES_HOST}:5432:${POSTGRES_DBNAME}:${POSTGRES_USER}:${POSTGRES_PASS}" > /var/www/.pgpass
chown www-data:www-data /var/www/.pgpass
chmod 600 /var/www/.pgpass

# add database creds to map config
envsubst \
    < ${CARTO_DIR}/project.mml.template \
    > ${CARTO_DIR}/project.mml

# populate data as user
sudo -E -u www-data /populate_map_data.sh

# make sure apache is running
service apache2 start

# run renderd in the foreground
sudo -u www-data renderd -f -c /usr/local/etc/renderd.conf
