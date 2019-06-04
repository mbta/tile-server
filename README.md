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

To generate all tile images at once, append `tiles` to the `docker run` command. You can also upload them directly to S3 by declaring the necessary environment variables:
* `MAPNIK_TILE_S3_BUCKET`: S3 bucket to upload tiles
* `AWS_ACCESS_KEY_ID`: AWS access key ID
* `AWS_SECRET_ACCESS_KEY`: AWS access key
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

### Publishing Tiles through AWS Batch

To generate tiles for production usage we use [AWS Batch tool](https://aws.amazon.com/batch/), which allows to execute multiple similar jobs in parallel. In order to use AWS Batch, the first prerequisite is to push the docker image into AWS ECR Repository. Tile server image is already there so this step is only required in case if you have done any changes to the image (that is, changes to dockerfiles itself or to the files used by it). In order to push the image to ECR Repository, execute following commands: 

* `$(aws ecr get-login --no-include-email --region us-east-1)`: login to ECR
* `docker build -t tile-server .`: build tile server docker image
* `docker tag tile-server:latest 434035161053.dkr.ecr.us-east-1.amazonaws.com/tile-server:latest`: tag the image with the version called "latest"
* `docker push 434035161053.dkr.ecr.us-east-1.amazonaws.com/tile-server:latest`: push (upload) docker image to the repository

These steps should normally be set up to run in CI system, but at the time of writing this we don't have one, so they need to be executed manually. 



Next step is to launch the AWS batch job(s) to generate the tiles through the uploaded docker image. Tiles are generated for a _service area_ defined in the source code: [generate_tiles.py](https://github.com/mbta/tile-server/blob/master/etc/generate_tiles.py#L195-L198). This area roughtly represents the area, which customers are believed to expect to see on the maps on the mbta.com website. If you change the area in the source code -- or do any other change there -- you need to rebuild the docker image and push it to the ECR repo (see above).

The idea behind running the jobs in AWS batch is that we split the _service area_ into horizontal (East-West) stripes and generate tiles for each of those map stripes independently. Since there is no overlap, the execution can be parallelized and we can have as many parallel jobs as we see necessary. 

In order to launch AWS Batch jobs, do the following:
* Login into AWS Console and navigate to AWS Batch: https://console.aws.amazon.com/batch/
* Go to "Job Definitions" section, click on "tile-generation-dev" item and then on the radio-button corresponding to the latest revision. 
* Click Actions -> Submit job
* On the next screen do the following:
  * Specify job name, which describes current job the best (no special requirements for the name)
  * Specify `tile-generation-dev-queue` as the job queue name. 
  * **Important**: specify **Array** as job type. 
  * Specify number of jobs to be run as parallel in Array Size field. If you don't know how many you need, put `8`. It took 5-6 hours for 8 jobs to generate the tiles for entire service area up to maximum zoom level (18 during previous tests. 
  * Navigate to **Environment variables** section and make sure that we have both mandatory variables set to correct values:
    * `MAPNIK_TILE_S3_BUCKET`: should correspond with the target S3 bucket; `mbta-map-tiles-dev` for dev environment or `mbta-map-tiles` for production environment. If you want to upload files to different bucket, you can specify it here as well, but make sure that batch jobs have permissions to write there. 
    * **Important**: `BATCH_JOB_COUNT`: should be equal to what you specified in Array Size field. Failure to set the right value here will result in either missing tiles or in overal between the jobs (they are going to generate the same tiles).
  * Click "Submit Job" and wait for jobs to run. You can also check Cloud Watch logs, while the jobs are running. Links to those logs are available from the Jobs page. 

These steps should also normally be set up to run in CI system, but at the time of writing this we don't have one, so they need to be executed manually. 