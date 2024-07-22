#!/usr/bin/env bash

# trigger the AWS Batch job to build tiles

# AWS Batch job queue
job_queue="tile-generation-dev-queue"
# AWS Batch job definition name
job_definition_name="tile-generation-dev"
# arbitrary name for the job we're submitting
job_name="tile-build-`date "+%Y-%m-%d-%H-%M-%S"`"

# get ARN of latest job definition revision
job_definition_arn="`aws batch describe-job-definitions \
    --job-definition-name "${job_definition_name}" \
    | jq -r '.jobDefinitions | max_by(.revision) | .jobDefinitionArn'`"


# submit the job
aws batch submit-job \
    --job-name "${job_name}" \
    --job-queue "${job_queue}" \
    --job-definition "${job_definition_arn}" \
    --array-properties "size=8"
