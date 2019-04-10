#!/bin/bash
set -e

service postgresql start
service apache2 restart

# load map data
sudo -H -u postgres /load_map_data.sh

# if 'tiles' is passed as a command to run, generate and publish tiles
if [ "$1" == "tiles" ]; then
    sudo -u postgres /var/lib/postgresql/src/generate_tiles.py
    if [ -n "${MAPNIK_TILE_S3_BUCKET}" ]; then
        cd /var/lib/mod_tile/ && aws s3 sync . "s3://${MAPNIK_TILE_S3_BUCKET}/" --size-only
    fi
fi

sudo -u postgres renderd -f -c /usr/local/etc/renderd.conf
