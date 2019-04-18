#!/bin/bash
set -e

service postgresql start

# load map data
sudo -H -u postgres /load_map_data.sh

# make sure all apache sites are disabled to start
for site in `ls -1 /etc/apache2/sites-enabled`; do
    a2dissite "${site#\.conf}"
done

# if 'kosmtik' is passed as a command to run, enter style editing mode
if [ "$1" == "kosmtik" ]; then
    a2ensite kosmtik
    service apache2 restart
    sudo -H -u postgres kosmtik serve /style/project.mml
fi

# if 'tiles' is passed as a command to run, generate and publish tiles
if [ "$1" == "tiles" ]; then
    sudo -E -u postgres /var/lib/postgresql/src/generate_tiles.py
    if [ -n "${MAPNIK_TILE_S3_BUCKET}" ]; then
        cd /var/lib/mod_tile/ && aws s3 sync . "s3://${MAPNIK_TILE_S3_BUCKET}/osm_tiles/" --size-only
        echo "AWS S3 sync has completed successfully"
    fi
fi

# if no commands were passed, run renderd
if [ "$#" -eq 0 ]; then
    a2ensite renderd
    service apache2 restart
    sudo -u postgres renderd -f -c /usr/local/etc/renderd.conf
fi
