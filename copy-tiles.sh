#!/bin/bash

# trigger the AWS Batch job to copy tiles between S3 buckets

# allow overriding the values of the SOURCE_S3_PATH and DESTINATION_S3_PATH
# env vars used by the container in the AWS Batch job
source_s3_path="${SOURCE_S3_PATH:-s3://mbta-map-tiles-dev/osm_tiles/}"
destination_s3_path="${DESTINATION_S3_PATH:-s3://mbta-map-tiles/osm_tiles/}"

# AWS Batch job queue
job_queue="tile-generation-prod-queue"
# AWS Batch job definition name
job_definition_name="tile-copy"
# arbitrary name for the job we're submitting
job_name="tile-copy-prod-`date "+%Y-%m-%d-%H-%M-%S"`"

# get ARN of latest job definition revision
job_definition_arn="`aws batch describe-job-definitions \
    --job-definition-name "${job_definition_name}" \
    | jq -r '.jobDefinitions | max_by(.revision) | .jobDefinitionArn'`"

# define env vars used by container
container_overrides="{\"environment\":[{\"name\":\"SOURCE_S3_PATH\",\"value\":\"${source_s3_path}\"},{\"name\":\"DESTINATION_S3_PATH\",\"value\":\"${destination_s3_path}\"}]}"

# submit the job
aws batch submit-job \
    --job-name "${job_name}" \
    --job-queue "${job_queue}" \
    --job-definition "${job_definition_arn}" \
    --container-overrides "${container_overrides}"
