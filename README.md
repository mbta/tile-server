# tile-server

OpenStreetMap tile server

## Development

To build the tile-server container, change to the root of the repo and run:

```bash
$ docker build -t tile-server .
```

See below for different ways to run the container once built.

## Run Modes

The container will load all map data automatically when started. There are three different modes for how to run it:

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

To generate all tile images at once, append `tiles` to the `docker run` command. You can also upload them directly to S3 by declaring the necessary environment variables.

```bash
$ docker run --tty \
    --name="tile-server" \
    --volume var-lib-postgres:/var/lib/postgresql \
    --env MAPNIK_TILE_S3_BUCKET="my-s3-bucket-name" \
    --env AWS_ACCESS_KEY_ID="my-aws-access-key-id" \
    --env AWS_SECRET_ACCESS_KEY="my-aws-secret-access-key" \
    --publish="80:80" tile-server tiles
```
