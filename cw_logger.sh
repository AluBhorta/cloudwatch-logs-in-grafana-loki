#!/bin/sh

LOG_GROUP_NAME="/freelance-client/10/sample-log-generator"  # Replace with your CloudWatch Logs group name
LOG_INTERVAL=30  # Adjust this value to the desired log interval in seconds

while true; do
  LOG_STREAM_NAME=from-tm-ec2_$(date -u +"%H-%M-%S")  

  aws logs create-log-stream \
    --log-group-name "${LOG_GROUP_NAME}" \
    --log-stream-name "${LOG_STREAM_NAME}"
  
  for n in {1..10}; do
    DATETIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    DATETIME_V2=$(date -u +"%Y%m%d%H%M%S")
    TIMESTAMP=$(date -u +%s%3N)
    MESSAGE="hi from $(uuidgen) at ${DATETIME} OR ${DATETIME_V2} | TS=${TIMESTAMP}"
  
    # Send the log message
    aws logs put-log-events \
    --log-group-name "${LOG_GROUP_NAME}" \
    --log-stream-name "${LOG_STREAM_NAME}" \
    --log-events "timestamp=${TIMESTAMP},message=${MESSAGE}"

    sleep ${LOG_INTERVAL}

  done

done
