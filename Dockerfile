FROM ubuntu:18.04
RUN apt-get -y update && apt-get -y install libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf\
  libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin\
  libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libtiff5-dev libicu-dev libgdal-dev\
  libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1\
  liblua5.1-dev libgeotiff-epsg curl

#install and configure Postgres
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install postgresql postgresql-contrib postgis postgresql-10-postgis-2.4 postgresql-10-postgis-scripts
USER postgres
RUN /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -E UTF8 -O docker gis &&\
    psql --dbname=gis --command "CREATE EXTENSION hstore;" &&\
    psql --dbname=gis --command "CREATE EXTENSION postgis;" &&\
    psql --dbname=gis --command "ALTER TABLE geometry_columns OWNER TO docker;" &&\
    psql --dbname=gis --command "ALTER TABLE spatial_ref_sys OWNER TO docker;" &&\
    /etc/init.d/postgresql stop

#build osm2pgsql
USER root
RUN git clone git://github.com/openstreetmap/osm2pgsql.git ~postgres/src/osm2pgsql --depth 1
RUN apt-get -y install make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev\
  zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev osmium-tool
RUN cd ~postgres/src/osm2pgsql && mkdir build && cd build && cmake .. && make && make install

#install Mapnik
RUN apt-get -y install autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev\
  libproj-dev gdal-bin libmapnik-dev mapnik-utils python-mapnik sudo

#build mod_tile and renderd
RUN git clone https://github.com/openstreetmap/mod_tile.git ~postgres/src/mod_tile --depth 1
RUN cd ~postgres/src/mod_tile && ./autogen.sh && ./configure && make && make install && make install-mod_tile && ldconfig

#build carto (map style configuration)
RUN git clone git://github.com/gravitystorm/openstreetmap-carto.git ~postgres/src/openstreetmap-carto --depth 1
RUN apt-get install -y npm nodejs
RUN npm install -g carto && cd ~postgres/src/openstreetmap-carto && ./scripts/get-shapefiles.py && carto project.mml > mapnik.xml
RUN sed -i 's^<Font face-name="unifont Medium" />^^' ~postgres/src/openstreetmap-carto/mapnik.xml
RUN chown -R postgres:postgres ~postgres/

#install fonts
RUN apt-get -y install fonts-noto-cjk fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-hanazono ttf-unifont

#load data
USER postgres
RUN mkdir ~/data && cd ~/data &&\
  wget http://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf &&\
  wget http://download.geofabrik.de/north-america/us/rhode-island-latest.osm.pbf

#merge map files
RUN osmium merge -v --progress ~/data/massachusetts-latest.osm.pbf ~/data/rhode-island-latest.osm.pbf -o ~/data/merged.osm.pbf

RUN /etc/init.d/postgresql start && osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script\
  ~/src/openstreetmap-carto/openstreetmap-carto.lua -C 5000 --number-processes 4\
  -S ~/src/openstreetmap-carto/openstreetmap-carto.style ~/data/merged.osm.pbf &&\
  /etc/init.d/postgresql stop

#configure renderd
USER root
COPY etc/renderd.conf /usr/local/etc/renderd.conf
RUN mkdir /var/lib/mod_tile && chown postgres:postgres /var/lib/mod_tile
RUN mkdir /var/run/renderd && chown postgres:postgres /var/run/renderd
COPY etc/default_renderd.sh /etc/default/renderd
RUN cp ~postgres/src/mod_tile/debian/renderd.init /etc/init.d/renderd && chmod a+x /etc/init.d/renderd
RUN rm /etc/apache2/sites-enabled/000-default.conf

# configure apache
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/mod_tile.load
RUN ln -s /etc/apache2/mods-available/mod_tile.load /etc/apache2/mods-enabled/
COPY etc/apache2_renderd.conf /etc/apache2/sites-available/renderd.conf
RUN ln -s /etc/apache2/sites-available/renderd.conf /etc/apache2/sites-enabled/renderd.conf

# additional fonts requred for pre-rendering
RUN cd /usr/share/fonts/truetype/noto/ && \
  wget https://github.com/googlei18n/noto-emoji/raw/master/fonts/NotoEmoji-Regular.ttf 

# test page
COPY ./index.html /var/www/html/
# health check
RUN touch /var/www/html/_health

COPY ./docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
EXPOSE 80

# generate tiles
COPY etc/generate_tiles.py /var/lib/postgresql/src/generate_tiles.py
RUN chmod a+x /var/lib/postgresql/src/generate_tiles.py
RUN apt-get -y install python-pip
RUN pip install awscli

USER postgres
RUN /etc/init.d/postgresql start && /var/lib/postgresql/src/generate_tiles.py && /etc/init.d/postgresql stop
RUN cd /var/lib/mod_tile/ && aws s3 sync . s3://mbta-map-tiles/ --size-only

CMD ["/docker-entrypoint.sh"]
