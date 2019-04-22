#!/bin/bash

set -e

completion_flagfile="${HOME}/map_data_loaded"

# test whether completion flagfile exists
if [ -f "${completion_flagfile}" ]; then
  one_week="604800"
  build_time=`date -r "${completion_flagfile}" +%s`
  now=`date +%s`
  age_of_build=$((${now} - ${build_time}))
  if [ "${age_of_build}" -gt "${one_week}" ]; then
    # TODO erase the data instead of just warning?
    echo "WARNING: Your map data is older than one week. Tiles may be outdated."
  fi
fi

# download map data
map_data_path="${HOME}/data"
if [ ! -f "${map_data_path}/merged.osm.pbf" ]; then
  mkdir "${map_data_path}"
  cd "${map_data_path}"
  wget http://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf
  wget http://download.geofabrik.de/north-america/us/rhode-island-latest.osm.pbf

  # merge map data
  osmium merge -v --progress \
    "${map_data_path}/massachusetts-latest.osm.pbf" \
    "${map_data_path}/rhode-island-latest.osm.pbf" \
    -o "${map_data_path}/merged.osm.pbf"
fi

# download shapefiles
shape_path="/style/shp"
if [ ! -d "${shape_path}" ]; then
  mkdir "${shape_path}" 
  cd "${shape_path}"
  wget http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.3.0/physical/10m-land.zip
  wget http://tilemill-data.s3.amazonaws.com/osm/coastline-good.zip
  wget http://tilemill-data.s3.amazonaws.com/osm/shoreline_300.zip
  wget http://mapbox-geodata.s3.amazonaws.com/natural-earth-1.4.0/cultural/10m-populated-places-simple.zip
  unzip "*.zip"
  find -iname '*.shp' -execdir shapeindex {} \;
  mkdir /style/output
  cd /style && ./make.py
  cd /style/output/OSMSmartrak && carto project.mml > mapnik.xml
  sed -i 's^<Font face-name="unifont Medium" />^^' mapnik.xml
fi

# populate database
if [ `psql -t --dbname="gis" --command="SELECT COUNT(*) from information_schema.tables WHERE table_name LIKE 'planet_osm_%';"` -eq 0 ]; then
  osm2pgsql -d gis --create --slim -G --hstore -C 5000 --number-processes 4 "${map_data_path}/merged.osm.pbf"
fi

# touch the flagfile at the end to verify completion
if [ ! -f "${completion_flagfile}" ]; then
  touch "${completion_flagfile}"
fi
