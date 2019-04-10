#!/bin/bash
set -e

service postgresql start
service apache2 restart

mkdir /var/lib/postgresql/data && cd /var/lib/postgresql/data &&\
  wget http://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf &&\
  wget http://download.geofabrik.de/north-america/us/rhode-island-latest.osm.pbf

osmium merge -v --progress /var/lib/postgresql/data/massachusetts-latest.osm.pbf \
    /var/lib/postgresql/data/rhode-island-latest.osm.pbf -o /var/lib/postgresql/data/merged.osm.pbf

sudo -u postgres osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script\
  /var/lib/postgresql/src/openstreetmap-carto/openstreetmap-carto.lua -C 5000 --number-processes 4\
  -S /var/lib/postgresql/src/openstreetmap-carto/openstreetmap-carto.style /var/lib/postgresql/data/merged.osm.pbf 

sudo -u postgres /var/lib/postgresql/src/generate_tiles.py 
cd /var/lib/mod_tile/ && aws s3 sync . s3://mbta-map-tiles/ --size-only

sudo -u postgres renderd -f -c /usr/local/etc/renderd.conf

/bin/bash
