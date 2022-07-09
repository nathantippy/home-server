#!/usr/bin/env bash
ROLE=${1:-"UNKNOWN"} 
DURATION=${2:-"3600"} 
REGION=${3:-"us-east-2"}
DESCRIPTION=${4:-"wrk"}
########################
ACCT=$(aws sts get-caller-identity --query Account --output text) || exit	
ASSUMED_ROLE=$(aws sts assume-role --duration-seconds ${DURATION} --role-arn arn:aws:iam::${ACCT}:role/${ROLE} --role-session-name ${DESCRIPTION}_${DURATION}s --output json) || exit
echo "${ASSUMED_ROLE}"
export ORIGINAL_AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export ORIGINAL_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}	
export AWS_ACCESS_KEY_ID=$(echo ${ASSUMED_ROLE} | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo ${ASSUMED_ROLE} | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo ${ASSUMED_ROLE} | jq -r '.Credentials.SessionToken')
export AWS_EXPIRATION=$(echo ${ASSUMED_ROLE} | jq -r '.Credentials.Expiration')
export AWS_DEFAULT_REGION=${REGION}

