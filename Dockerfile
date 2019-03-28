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
  zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev
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
RUN chown -R postgres:postgres ~postgres/

#install fonts
RUN apt-get -y install fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont

#load data
USER postgres
RUN mkdir ~/data && cd ~/data &&\
  wget http://download.geofabrik.de/north-america/us/massachusetts-latest.osm.pbf
RUN /etc/init.d/postgresql start && osm2pgsql -d gis --create --slim  -G --hstore --tag-transform-script\
  ~/src/openstreetmap-carto/openstreetmap-carto.lua -C 10000 --number-processes 4\
  -S ~/src/openstreetmap-carto/openstreetmap-carto.style ~/data/massachusetts-latest.osm.pbf &&\
  /etc/init.d/postgresql stop

#configure apache and renderd
USER root
RUN sed -i 's/XML=\/home\/jburgess\/osm\/svn\.openstreetmap\.org\/applications\/rendering\/mapnik\/osm\-local\.xml/XML=\/var\/lib\/postgresql\/src\/openstreetmap-carto\/mapnik.xml/' /usr/local/etc/renderd.conf
RUN sed -i 's/HOST=tile\.openstreetmap\.org/HOST=localhost/' /usr/local/etc/renderd.conf
RUN sed -i 's/plugins_dir=\/usr\/lib\/mapnik\/input/plugins_dir=\/usr\/lib\/mapnik\/3.0\/input\//' /usr/local/etc/renderd.conf
RUN sed -i '/^;/ d' /usr/local/etc/renderd.conf
RUN mkdir /var/lib/mod_tile && chown postgres:postgres /var/lib/mod_tile
RUN mkdir /var/run/renderd && chown postgres:postgres /var/run/renderd
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/mod_tile.load
RUN ln -s /etc/apache2/mods-available/mod_tile.load /etc/apache2/mods-enabled/
RUN sed -i '/<\/VirtualHost>/ i \
LoadTileConfigFile \/usr\/local\/etc\/renderd.conf \n \
ModTileRenderdSocketName \/var\/run\/renderd\/renderd.sock \n \
ModTileRequestTimeout 0 \n \
ModTileMissingRequestTimeout 30' /etc/apache2/sites-enabled/000-default.conf
RUN sed -i 's/DAEMON=\/usr\/bin\/$NAME/DAEMON=\/usr\/local\/bin\/$NAME/' ~postgres/src/mod_tile/debian/renderd.init 
RUN sed -i 's/DAEMON_ARGS=""/DAEMON_ARGS=" -c \/usr\/local\/etc\/renderd.conf"/' ~postgres/src/mod_tile/debian/renderd.init 
RUN sed -i 's/RUNASUSER=www-data/RUNASUSER=postgres/' ~postgres/src/mod_tile/debian/renderd.init 
RUN cp ~postgres/src/mod_tile/debian/renderd.init /etc/init.d/renderd && chmod a+x /etc/init.d/renderd

COPY ./index.html /var/www/html/

COPY ./docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
EXPOSE 80
CMD ["/docker-entrypoint.sh"]
