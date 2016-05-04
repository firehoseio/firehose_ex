#!/bin/bash
#set -e

if [[ "$REDIS_HOST" == "" ]]; then
  echo '$REDIS_HOST must be set'
  exit 1
fi

escaped_val="$(echo "$REDIS_HOST" | sed -e 's/\./\\./g' -e 's/\//\\\//g')"
sed -i "s/PLACEHOLDER_REDIS_HOST_PLACEHOLDER/$escaped_val/g" /etc/dd-agent/conf.d/redisdb.yaml
