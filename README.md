# tile-server

OpenStreetMap tile server

## Purpose

The goal of this repository is to facilitate the creation of a Docker container that encapsulates all the elements necessary to develop map tiles for use on MBTA.com. The resulting tile images are published to S3.

The styles used are modified versions of the [OSM Smartrak](https://github.com/jacobtoye/osm-bright) theme, itself a derivative of the [OSM Bright](https://github.com/mapbox/osm-bright) theme. Copies of the relevant license information can be found in the directories containing code derived from that project, namely `etc/osm-bright/LICENSE.txt`, `etc/default-style/LICENSE.txt`, and `etc/skate-style/LICENSE.txt`.

## Development

To build the tile-server container, change to the root of the repo and run:

```bash
$ docker build -t tile-server .
```

See below for different ways to run the container once built.

## Pushing Image

To build the container and push it, run:

```bash
DOCKER_SERVER=[Docker server URL] build_push.sh [tag]
```

Usually, the tag argument we provide is of the form `git-[commit hash]`. The script will also apply the `latest` tag.

## Map Styling and Coverage

The default styling of the map is optimized for [mbta.com](https://www.mbta.com/). There is also a style intended primarily for use with [Skate](https://github.com/mbta/skate). Which style is used can be changed by using the `STYLE_DIR` environment variable, using a value of either `default` (the default if not set explicitly) or `skate`.

In addition, the `MAP_TYPE` environment variable can be used to customize the coverage area. By default, a coverage area including eastern Massachusetts, Rhode Island, and southern New Hampshire is used. The boundaries of this area are defined in the source code in [`generate_tiles.py`](https://github.com/mbta/tile-server/blob/master/etc/generate_tiles.py#L200-L204). In addition, the OSM data files to fetch are determined in `load_map_data.sh`. For a demonstration of how to add data for additional states, see [this PR](https://github.com/mbta/tile-server/pull/12/files). In addition to the default area if no input is provided, setting `MAP_TYPE` to `bus` will pull data and build tiles for a somewhat smaller area, roughly corresponding to the area within I-495 to conservatively capture the entire MBTA bus service area.

### Shield Styling

Shields are used for text labels with a background image, such as highway and exit labels. By default, the [OSM Smartrak shields](https://github.com/jacobtoye/osm-bright/tree/master/themes/osm-smartrak/img) are available for use in style files. To add new shields, edit the configuration of the `generate_shields.py` script, starting with adding a new [type](https://github.com/mbta/tile-server/blob/master/generate_shields.py#L34).
To output new shield image files, make sure python 3 is installed and run:

```bash
$ python generate_shields.py
```

## Run Modes

The container will load all map data automatically when started. There are four different modes for how to run it:

### Renderd

By default, the container will run Apache and renderd on port 80.

```bash
$ docker run --tty \
    --name="tile-server" \
    --publish="80:80" tile-server
```

Renderd logs will stream to stdout, and tile images will be generated on demand. However, by default no map data will be preserved when the container is deleted. To preserve map data across container runs, create a volume for `/var/lib/postgresql` at launch. Volumes will persist if the container is removed, and can be reused with future containers.

```bash
$ docker run --tty --name="tile-server" \
    --volume var-lib-postgres:/var/lib/postgresql \
    --publish="80:80" tile-server
```

Note that since map data is subject to change, it may be worth deleting and rebuilding the `var-lib-postgres` volume on occasion.

It's also possible to preserve tile image data if desired, by creating a volume for `/var/lib/mod_tile`:

```bash
$ docker run --tty --name="tile-server" \
    --volume var-lib-mod-tile:/var/lib/mod_tile \
    --publish="80:80" tile-server
```

### Kosmtik

To facilitate tile image customization, [Kosmtik](https://github.com/kosmtik/kosmtik) can be run instead of renderd, by appending `kosmtik` to the `docker run` command. In this case it's also useful to mount the `style/` directory into the container. Kosmtik will watch the files in the style directory for changes and automatically re-generate the tile images in view.

```bash
$ docker run --tty \
    --name="tile-server" \
    --volume var-lib-postgres:/var/lib/postgresql \
    --volume `pwd`/style:/style \
    --publish="80:80" tile-server kosmtik
```

### Build & Publish Tiles

To generate all tile images at once, append `tiles` to the `docker run` command. You can also upload them directly to S3 by declaring the necessary environment variables:

- `MAPNIK_TILE_S3_BUCKET`: S3 bucket to upload tiles
- `S3_SUBDIRECTORY`: directory within the bucket to place the tiles. Defaults to `osm_tiles`.
- `AWS_ACCESS_KEY_ID`: AWS access key ID
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key
- `S3_FORCE_OVERWRITE`: controls how files are uploaded to S3; if set to "1" then all files will be uploaded, otherwise only the changed files will be uploaded. Whether the file has been changed is determined by the file size. It is recommended to set this flag whenever map style is modified, because if the only thing that is changed for a map tile is its color, then the file size is going to remain the same and the tile is not going to be uploaded

Example:

```bash
$ docker run --tty \
    --name="tile-server" \
    --volume var-lib-postgres:/var/lib/postgresql \
    --env MAPNIK_TILE_S3_BUCKET="my-s3-bucket-name" \
    --env AWS_ACCESS_KEY_ID="my-aws-access-key-id" \
    --env AWS_SECRET_ACCESS_KEY="my-aws-secret-access-key" \
    --env S3_FORCE_OVERWRITE="1" \
    --publish="80:80" tile-server tiles
```

#### AWS Batch

The tile generation mode is optimized for running in [AWS Batch](https://aws.amazon.com/batch/), which allows multiple similar jobs to be executed in parallel.

The idea behind generating tiles via AWS batch is that we split the _service area_ into horizontal (East-West) stripes and generate tiles for each of those map stripes independently. Since there is no overlap, the execution can be parallelized and we can have as many parallel jobs as we see necessary.

Important thing to note is that the service area only make sense if we have the map data for it. Currently we have map data for MA, RI and NH, so if you need service area to cover any other territories, you need to add map data first ([example PR](https://github.com/mbta/tile-server/pull/12/files)).

The generate_tiles.py script uses the following environment variables to determine which tiles to generate:

- `AWS_BATCH_JOB_ARRAY_INDEX`: The numerical index representing which stripe of tiles a specific container should generate, e.g. `0`, `1`, … _`n`_. This is set automatically by AWS Batch and can't be overridden.
- `BATCH_JOB_COUNT`: The total number of stripes in the current job. This should be equal to what is specified in the "Array Size" field in the AWS Batch job configuration. Failure to set the right value here will result in either missing tiles or in overlap between the slices generated by each container.

### Copy Tiles Between S3 Buckets

This container can also be used to copy tiles between S3 buckets. This operation makes use of the [AWS CLI](https://aws.amazon.com/cli/). Copying tiles does not depend on any of the other software included in the container, and could be run separately, but the functionality is included for the convenience of being able to run all tile-related operations in the same environment.

To copy tiles, append `copy` to the `docker run` command, and declare the following environment variables:

- `SOURCE_S3_PATH`: S3 bucket where the tiles are located
- `DESTINATION_S3_PATH`: S3 bucket to copy tiles into
- `AWS_ACCESS_KEY_ID`: AWS access key ID
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key

Example:

```bash
$ docker run --tty \
    --name="tile-server" \
    --volume var-lib-postgres:/var/lib/postgresql \
    --env SOURCE_S3_PATH="s3://my-s3-bucket-name/tile_path/" \
    --env DESTINATION_S3_PATH="s3://other-s3-bucket-name/tile_path/" \
    --env AWS_ACCESS_KEY_ID="my-aws-access-key-id" \
    --env AWS_SECRET_ACCESS_KEY="my-aws-secret-access-key" \
    --publish="80:80" tile-server copy
```
