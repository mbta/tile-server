# tile-server

OpenStreetMap tile server

## Purpose

The goal of this repository is to facilitate the creation of a Docker container that encapsulates all the elements necessary to develop map tiles for use on MBTA.com. The resulting tile images are published to S3.

## Development

To build the tile-server container, change to the root of the repo and run:

```bash
$ docker build -t tile-server .
```

See below for different ways to run the container once built.

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

* `MAPNIK_TILE_S3_BUCKET`: S3 bucket to upload tiles
* `AWS_ACCESS_KEY_ID`: AWS access key ID
* `AWS_SECRET_ACCESS_KEY`: AWS secret access key
* `S3_FORCE_OVERWRITE`: controls how files are uploaded to S3; if set to "1" then all files will be uploaded, otherwise only the changed files will be uploaded. Whether the file has been changed is determined by the file size. It is recommended to set this flag whenever map style is modified, because if the only thing that is changed for a map tile is its color, then the file size is going to remain the same and the tile is not going to be uploaded

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

When the tile generation job is run, tiles are generated for a _service area_ defined in the source code: [generate_tiles.py](https://github.com/mbta/tile-server/blob/master/etc/generate_tiles.py#L195-L198). This area roughtly represents the area which customers are believed to expect to see on the maps on the mbta.com website. If you change the area in the source code -- or do any other change there -- you need to rebuild and publish a new version of the Docker image.

The idea behind generating tiles via AWS batch is that we split the _service area_ into horizontal (East-West) stripes and generate tiles for each of those map stripes independently. Since there is no overlap, the execution can be parallelized and we can have as many parallel jobs as we see necessary.

Important thing to note is that the service area only make sense if we have the map data for it. Currently we have map data for MA, RI and NH, so if you need service area to cover any other territories, you need to add map data first ([example PR](https://github.com/mbta/tile-server/pull/12/files)).

The generate_tiles.py script uses the following environment variables to determine which tiles to generate:

* `AWS_BATCH_JOB_ARRAY_INDEX`: The numerical index representing which stripe of tiles a specific container should generate, e.g. `0`, `1`, … _`n`_. This is set automatically by AWS Batch and can't be overridden.
* `BATCH_JOB_COUNT`: The total number of stripes in the current job. This should be equal to what is specified in the "Array Size" field in the AWS Batch job configuration. Failure to set the right value here will result in either missing tiles or in overlap between the slices generated by each container.

### Copy Tiles Between S3 Buckets

This container can also be used to copy tiles between S3 buckets. This operation makes use of the [AWS CLI](https://aws.amazon.com/cli/). Copying tiles does not depend on any of the other software included in the container, and could be run separately, but the functionality is included for the convenience of being able to run all tile-related operations in the same environment.

To copy tiles, append `copy` to the `docker run` command, and declare the following environment variables:

* `SOURCE_S3_PATH`: S3 bucket where the tiles are located
* `DESTINATION_S3_PATH`: S3 bucket to copy tiles into
* `AWS_ACCESS_KEY_ID`: AWS access key ID
* `AWS_SECRET_ACCESS_KEY`: AWS secret access key

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
