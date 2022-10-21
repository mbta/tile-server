#!/bin/bash
set -e -x -u

# required configuration:
# * DOCKER_SERVER (from ECR)

app=tile-server
tag=$1

# build docker image and tag it with git hash and aws environment
docker build -t $app:"$tag" -t $app:latest -t "$DOCKER_SERVER"/$app:"$tag" -t "$DOCKER_SERVER"/$app:latest .

# retrieve the `docker login` password from AWS ECR and use it
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$DOCKER_SERVER"

# push images to ECS image repo
docker image push --all-tags "$DOCKER_SERVER"/$app
