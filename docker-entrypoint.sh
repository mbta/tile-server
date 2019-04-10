#!/bin/bash
set -e

service postgresql start
service apache2 restart

# load map data
sudo -H -u postgres /load_map_data.sh

sudo -u postgres /var/lib/postgresql/src/generate_tiles.py
cd /var/lib/mod_tile/ && aws s3 sync . s3://mbta-map-tiles/ --size-only

sudo -u postgres renderd -f -c /usr/local/etc/renderd.conf
