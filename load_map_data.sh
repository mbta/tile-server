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
  for filename in massachusetts-latest.osm.pbf rhode-island-latest.osm.pbf new-hampshire-latest.osm.pbf; do
    wget --tries=100 --retry-on-http-error=429 --waitretry=100 --random-wait \
      http://download.geofabrik.de/north-america/us/$filename
  done

  # merge map data
  osmium merge -v --progress \
    "${map_data_path}/massachusetts-latest.osm.pbf" \
    "${map_data_path}/rhode-island-latest.osm.pbf" \
    "${map_data_path}/new-hampshire-latest.osm.pbf" \
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
  # additional fonts requred for tile generation
  cp -R /style/themes/osm-bright/fonts /style/output/OSMSmartrak/
  cd /style/output/OSMSmartrak/fonts && wget "https://assets.ubuntu.com/v1/fad7939b-ubuntu-font-family-0.83.zip"
  unzip "fad7939b-ubuntu-font-family-0.83.zip" && cd ubuntu-font-family-* && cp * ../
  cd /style/output/OSMSmartrak/fonts && wget "https://www.freedesktop.org/software/fontconfig/webfonts/webfonts.tar.gz"
  tar -xzf webfonts.tar.gz && cd msfonts && cabextract *.exe && cp *.ttf *.TTF /style/output/OSMSmartrak/fonts/
  cd /style/output/OSMSmartrak && sed -i 's^<Font face-name="unifont Medium" />^^' mapnik.xml
fi

# populate database
if [ `psql -t --dbname="gis" --command="SELECT COUNT(*) from information_schema.tables WHERE table_name LIKE 'planet_osm_%';"` -eq 0 ]; then
  osm2pgsql -d gis --create --slim -G --hstore -C 5000 --number-processes 4 "${map_data_path}/merged.osm.pbf"
fi

# touch the flagfile at the end to verify completion
if [ ! -f "${completion_flagfile}" ]; then
  touch "${completion_flagfile}"
fi
