#!/usr/bin/env python

from os import path
from collections import defaultdict
config = defaultdict(defaultdict)

config["theme"] = "osm-smartrak" # the folder the theme is located in ('osm-bright' or 'osm-smartrak')

config["importer"] = "osm2pgsql" # either 'imposm' or 'osm2pgsql'

# The name given to the style. This is the name it will have in the TileMill
# project list, and a sanitized version will be used as the directory name
# in which the project is stored
config["name"] = "OSM Smartrak"

# The absolute path to your MapBox projects directory. You should 
# not need to change this unless you have configured TileMill specially
config["path"] = path.expanduser("/style/output")

# PostGIS connection setup
# Leave empty for Mapnik defaults. The only required parameter is dbname.
config["postgis"]["host"]     = "localhost"
config["postgis"]["port"]     = "5432"
config["postgis"]["dbname"]   = "gis"
config["postgis"]["user"]     = "docker"
config["postgis"]["password"] = "docker"

# Increase performance if you are only rendering a particular area by
# specifying a bounding box to restrict queries. Format is "XMIN,YMIN,XMAX,YMAX"
# in the same units as the database (probably spherical mercator meters). The
# whole world is "-20037508.34 -20037508.34 20037508.34 20037508.34".
# Leave blank to let Mapnik estimate.
config["postgis"]["extent"] = ""

# Land shapefiles required for the style. If you have already downloaded
# these or wish to use different versions, specify their paths here.
# OSM land shapefiles from MapBox are indexed for Mapnik and have blatant 
# errors corrected (eg triangles along the 180 E/W line), but are updated
# infrequently. The latest versions can be downloaded from osm.org:
# - http://tile.openstreetmap.org/processed_p.tar.bz2
# - http://tile.openstreetmap.org/shoreline_300.tar.bz2
config["processed_p"] = "/style/shp/coastline-good.shp"
config["shoreline_300"] = "/style/shp/shoreline_300.shp"
