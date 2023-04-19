#!/bin/sh

LOG_GROUP_NAME="/freelance-client/10/sample-log-generator"
LOG_STREAM_NAME="from-tm-ec2"
LOG_INTERVAL=10  

# NOTE: make sure you create the log stream first
#   aws logs create-log-stream \
#     --log-group-name "${LOG_GROUP_NAME}" \
#     --log-stream-name "${LOG_STREAM_NAME}"

while true; do
  DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  DATETIME_V2=$(date -u +"%Y%m%d%H%M%S")
  TIMESTAMP=$(date -u +%s%3N)
  MESSAGE="hi from $(uuidgen) at ${DATETIME} OR ${DATETIME_V2}. TS=${TIMESTAMP}"

  # Send the log message
  aws logs put-log-events \
    --log-group-name "${LOG_GROUP_NAME}" \
    --log-stream-name "${LOG_STREAM_NAME}" \
    --log-events "timestamp=${TIMESTAMP},message=${MESSAGE}"

  sleep ${LOG_INTERVAL}
done
