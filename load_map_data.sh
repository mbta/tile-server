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
style_path="${HOME}/src/openstreetmap-carto"
if [ ! -d "${style_path}/data" ]; then
  cd "${style_path}"
  scripts/get-shapefiles.py
fi
# generate mapnik.xml
if [ ! -f "${style_path}/mapnik.xml" ]; then
  cd "${style_path}"
  carto project.mml > mapnik.xml
  # https://ircama.github.io/osm-carto-tutorials/tile-server-ubuntu/#old-unifont-medium-font
  sed -i 's^<Font face-name="unifont Medium" />^^' mapnik.xml
fi

# populate database
if [ `psql -t --dbname="gis" --command="SELECT COUNT(*) from information_schema.tables WHERE table_name LIKE 'planet_osm_%';"` -eq 0 ]; then
  osm2pgsql -d gis --create --slim -G --hstore \
  --tag-transform-script "${style_path}/openstreetmap-carto.lua" \
    -C 5000 --number-processes 4 \
    -S "${style_path}/openstreetmap-carto.style" "${map_data_path}/merged.osm.pbf"
fi

# touch the flagfile at the end to verify completion
if [ ! -f "${completion_flagfile}" ]; then
  touch "${completion_flagfile}"
fi
