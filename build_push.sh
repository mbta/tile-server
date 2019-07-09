#!/bin/bash
set -e -x -u

# required configuration:
# * APP
# * DOCKER_REPO

tag="${1:-latest}"

# build docker image and tag it with git hash and aws environment
docker build -t $APP:$tag .
docker tag $APP:$tag $DOCKER_REPO:$tag

# retrieve the `docker login` command from AWS ECR and execute it
logincmd=$(aws ecr get-login --no-include-email --region us-east-1)
eval $logincmd

# push images to ECS image repo
docker push $DOCKER_REPO:$tag
