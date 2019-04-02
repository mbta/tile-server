FROM ubuntu:18.04
RUN apt-get -y update && apt-get -y install libboost-all-dev git-core tar unzip wget bzip2 build-essential autoconf\
  libtool libxml2-dev libgeos-dev libgeos++-dev libpq-dev libbz2-dev libproj-dev munin-node munin\
  libprotobuf-c0-dev protobuf-c-compiler libfreetype6-dev libtiff5-dev libicu-dev libgdal-dev\
  libcairo-dev libcairomm-1.0-dev apache2 apache2-dev libagg-dev liblua5.2-dev ttf-unifont lua5.1\
  liblua5.1-dev libgeotiff-epsg curl

#build osm2pgsql
USER root
RUN git clone git://github.com/openstreetmap/osm2pgsql.git ~www-data/src/osm2pgsql --depth 1
RUN apt-get -y install make cmake g++ libboost-dev libboost-system-dev libboost-filesystem-dev libexpat1-dev\
  zlib1g-dev libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev lua5.2 liblua5.2-dev
RUN cd ~www-data/src/osm2pgsql && mkdir build && cd build && cmake .. && make && make install

#install Mapnik
RUN apt-get -y install autoconf apache2-dev libtool libxml2-dev libbz2-dev libgeos-dev libgeos++-dev\
  libproj-dev gdal-bin libmapnik-dev mapnik-utils python-mapnik sudo

#build mod_tile and renderd
RUN git clone https://github.com/openstreetmap/mod_tile.git ~www-data/src/mod_tile --depth 1
RUN cd ~www-data/src/mod_tile && ./autogen.sh && ./configure && make && make install && make install-mod_tile && ldconfig

#build carto (map style configuration)
RUN git clone git://github.com/gravitystorm/openstreetmap-carto.git ~www-data/src/openstreetmap-carto --depth 1
RUN apt-get install -y npm nodejs
RUN npm install -g carto
# copy in our style config template, to be expanded at runtime with db credentials
COPY project.mml /var/www/src/openstreetmap-carto/project.mml.template

RUN chown -R www-data:www-data ~www-data/

#install fonts
RUN apt-get -y install fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted ttf-unifont

# create data directory to be used at runtime
USER www-data
RUN mkdir ~/data

#configure renderd
USER root
COPY etc/renderd.conf /usr/local/etc/renderd.conf
RUN mkdir /var/lib/mod_tile && chown www-data:www-data /var/lib/mod_tile
RUN mkdir /var/run/renderd && chown www-data:www-data /var/run/renderd
COPY etc/default_renderd.sh /etc/default/renderd
RUN cp ~www-data/src/mod_tile/debian/renderd.init /etc/init.d/renderd && chmod a+x /etc/init.d/renderd
RUN rm /etc/apache2/sites-enabled/000-default.conf

# configure apache
RUN echo "LoadModule tile_module /usr/lib/apache2/modules/mod_tile.so" > /etc/apache2/mods-available/mod_tile.load
RUN ln -s /etc/apache2/mods-available/mod_tile.load /etc/apache2/mods-enabled/
COPY etc/apache2_renderd.conf /etc/apache2/sites-available/renderd.conf
RUN ln -s /etc/apache2/sites-available/renderd.conf /etc/apache2/sites-enabled/renderd.conf

# test page
COPY ./index.html /var/www/html/
# vague approximation of a health check
RUN touch /var/www/html/_health

# add setup scripts
COPY ./populate_map_data.sh /populate_map_data.sh
RUN chmod +x /populate_map_data.sh
COPY ./docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/docker-entrypoint.sh"]
