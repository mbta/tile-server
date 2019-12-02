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
RUN apt-get install -y npm nodejs
RUN npm install -g carto

# install kosmtik
RUN npm -g install kosmtik

#install fonts
RUN apt-get -y install fonts-noto-cjk fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted fonts-hanazono ttf-unifont\
  ttf-dejavu ttf-dejavu-core ttf-dejavu-extra cabextract

#configure renderd
USER root
COPY etc/renderd.conf /usr/local/etc/renderd.conf
RUN mkdir /var/lib/mod_tile && chown postgres:postgres /var/lib/mod_tile
RUN mkdir /var/run/renderd && chown postgres:postgres /var/run/renderd
COPY etc/default_renderd.sh /etc/default/renderd
RUN cp ~postgres/src/mod_tile/debian/renderd.init /etc/init.d/renderd && chmod a+x /etc/init.d/renderd
RUN rm /etc/apache2/sites-enabled/000-default.conf

# configure apache
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/tile.load
RUN a2enmod tile
RUN a2enmod proxy
RUN a2enmod proxy_http
COPY etc/apache2_renderd.conf /etc/apache2/sites-available/renderd.conf
COPY etc/apache2_kosmtik.conf /etc/apache2/sites-available/kosmtik.conf

# additional fonts requred for pre-rendering
RUN cd /usr/share/fonts/truetype/noto/ && \
  wget https://github.com/googlei18n/noto-emoji/raw/master/fonts/NotoEmoji-Regular.ttf

# generate tile scripts
RUN apt-get -y install python-pip
RUN pip install awscli
RUN aws configure set default.s3.max_concurrent_requests 100
COPY etc/generate_tiles.py /var/lib/postgresql/src/generate_tiles.py
RUN chmod a+x /var/lib/postgresql/src/generate_tiles.py

# install tilemill
RUN git clone https://github.com/tilemill-project/tilemill.git ~postgres/src/tilemill --depth 1
RUN cd ~postgres/src/tilemill && npm install

# install and configure styles
RUN git clone https://github.com/jacobtoye/osm-bright.git /style --depth 1
COPY etc/configure.py /style/configure.py
COPY etc/osm-smartrak.osm2pgsql.mml /style/themes/osm-smartrak/osm-smartrak.osm2pgsql.mml
COPY etc/palette.mss /style/themes/osm-smartrak/palette.mss
# fix for https://github.com/mapbox/osm-bright/issues/109
COPY etc/labels.mss /style/themes/osm-smartrak/labels.mss

# fix permissions
RUN chown -R postgres:postgres ~postgres/
RUN chown -R postgres:postgres /style

# copy test pages
COPY ./local.html /var/www/html/
COPY ./prod.html /var/www/html/
COPY ./dev.html /var/www/html/
# simulate a health check
RUN touch /var/www/html/_health

# copy map data loader script
COPY ./load_map_data.sh /
RUN chmod +x load_map_data.sh

COPY ./docker-entrypoint.sh /
RUN chmod +x docker-entrypoint.sh
EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
