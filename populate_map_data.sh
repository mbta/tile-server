#!/bin/bash
set -e

# script to retrieve and populate map data
# must be run as www-data user

# fail if these env vars are missing
export POSTGRES_HOST="${POSTGRES_HOST:?Error: POSTGRES_HOST not set}"
export POSTGRES_DBNAME="${POSTGRES_DBNAME:?Error: POSTGRES_DBNAME not set}"
export POSTGRES_USER="${POSTGRES_USER:?Error: POSTGRES_USER not set}"
export POSTGRES_PASS="${POSTGRES_PASS:?Error: POSTGRES_PASS not set}"

# declare some paths
# TODO consolidate these into parent script?
CARTO_DIR="/var/www/src/openstreetmap-carto"
DATA_DIR="/var/www/data"

# get map data
${CARTO_DIR}/scripts/get-shapefiles.py \
    && carto ${CARTO_DIR}/project.mml > ${CARTO_DIR}/mapnik.xml
wget http://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf \
    -O ${DATA_DIR}/massachusetts-latest.osm.pbf

# put map data in
# TODO optionally update instead of creating
osm2pgsql \
    --host ${POSTGRES_HOST} \
    --database ${POSTGRES_DBNAME} \
    --username ${POSTGRES_USER} \
    --create --slim  -G --hstore \
    --tag-transform-script ${CARTO_DIR}/openstreetmap-carto.lua \
    -C 5000 --number-processes 4 \
    -S ${CARTO_DIR}/openstreetmap-carto.style ${DATA_DIR}/massachusetts-latest.osm.pbf
