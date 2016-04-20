#!/bin/sh

set -e

if [[ "$FIREHOSE_PUBLISH_PASSWORD" == "" ]]; then
  echo '$FIREHOSE_PUBLISH_PASSWORD must not be empty.'
  exit 1
fi

if [[ "$FIREHOSE_PUBLISH_USER" == "" ]]; then
  echo '$FIREHOSE_PUBLISH_USER must not be empty.'
  exit 1
fi

echo "$FIREHOSE_PUBLISH_USER:$FIREHOSE_PUBLISH_PASSWORD" > /etc/nginx/htpasswd
echo "$FIREHOSE_PINGER_USER:$FIREHOSE_PINGER_PASSWORD" >> /etc/nginx/htpasswd
echo "$FIREHOSE_PUBLISH_USER2:$FIREHOSE_PUBLISH_PASSWORD2" >> /etc/nginx/htpasswd

chown -R nginx:nginx /var/lib/nginx

/usr/sbin/nginx
