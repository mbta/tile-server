FROM node:22.23.4-bookworm-slim AS node

FROM ubuntu:22.04 AS runtime
RUN apt-get update && apt-get -y install ca-certificates libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf\
  libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin\
  libprotobuf-c-dev protobuf-c-compiler libfreetype6-dev libtiff5-dev libicu-dev libgdal-dev\
  libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev fonts-unifont lua5.1\
  liblua5.1-dev proj-data curl gnupg
RUN dpkg --compare-versions "$(dpkg-query -W -f='${Version}' ca-certificates)" ge 20260816ubuntu0.22.04.1

#install and configure Postgres
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install postgresql postgresql-contrib postgis postgresql-14-postgis-3 postgresql-14-postgis-3-scripts
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
RUN git clone https://github.com/openstreetmap/osm2pgsql.git ~postgres/src/osm2pgsql --depth 1 --branch 1.8.1
RUN apt-get -y install make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev\
  zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev osmctools
RUN cd ~postgres/src/osm2pgsql && mkdir build && cd build && cmake .. && make && make install

#install Mapnik
RUN apt-get -y install autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev\
  libproj-dev gdal-bin libmapnik-dev mapnik-utils python3-mapnik sudo

#install mod_tile and renderd
RUN apt-get -y install libapache2-mod-tile renderd && a2disconf renderd

# Install a Node.js release with the eMudhra intermediate CA fix.
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/ /usr/local/lib/node_modules/
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
  dpkg --compare-versions "$(node --version | sed 's/^v//')" ge 22.23.4
ENV NODE_OPTIONS=--use-openssl-ca
RUN npm config set cafile /etc/ssl/certs/ca-certificates.crt

#build carto (map style configuration)
RUN npm install -g carto

# The npm release still pins Mapnik bindings for obsolete Node.js versions.
RUN npm install --prefix /opt/kosmtik https://github.com/kosmtik/kosmtik/archive/e2e4d1a626f1142f95e1adc60adc9c1e4c89ec00.tar.gz && \
  ln -s /opt/kosmtik/node_modules/.bin/kosmtik /usr/local/bin/kosmtik

#install fonts
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list && \
  apt-get -o Acquire::https::Timeout=120 -o Acquire::Retries=3 -y install fonts-noto-cjk fonts-noto-core fonts-noto-extra fonts-hanazono fonts-unifont\
  fonts-dejavu fonts-dejavu-core fonts-dejavu-extra cabextract

#configure renderd
USER root
COPY etc/renderd.conf /usr/local/etc/renderd.conf
RUN mkdir -p /var/lib/mod_tile && chown postgres:postgres /var/lib/mod_tile
RUN mkdir -p /var/run/renderd && chown postgres:postgres /var/run/renderd
COPY etc/default_renderd.sh /etc/default/renderd
RUN rm /etc/apache2/sites-enabled/000-default.conf

# configure apache
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/tile.load
RUN a2enmod tile
RUN a2enmod proxy
RUN a2enmod proxy_http
COPY etc/apache2_renderd.conf /etc/apache2/sites-available/renderd.conf
COPY etc/apache2_kosmtik.conf /etc/apache2/sites-available/kosmtik.conf

# additional fonts required for pre-rendering
RUN apt-get -y install fonts-noto-color-emoji

# generate tile scripts
RUN apt-get -y install awscli
ENV AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
RUN aws configure set default.s3.max_concurrent_requests 100
COPY etc/generate_tiles.py /var/lib/postgresql/src/generate_tiles.py

# install and configure styles
COPY etc/configure.py /style/configure.py

COPY etc/osm-smartrak/make.py /style/make.py
COPY etc/osm-smartrak/utils.py /style/utils.py

# add base styles to each theme directory first. The files specified in each theme directory may override these.
COPY etc/osm-smartrak/style /style/themes/default/
COPY etc/osm-smartrak/style /style/themes/skate/

COPY etc/default-style /style/themes/default/
COPY etc/skate-style /style/themes/skate/

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

COPY ./docker-entrypoint.sh /

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
