FROM datadog/docker-dd-agent

RUN echo "deb http://http.debian.net/debian jessie-backports main" >> /etc/apt/sources.list \
    && apt-get -q -y update \
    && apt-get -q -y install docker.io \
    && apt-get -q -y clean \
    && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

RUN sed -i -e"s/^.*use_dogstatsd:.*$/use_dogstatsd: no/" /etc/dd-agent/datadog.conf

COPY *.yaml /etc/dd-agent/conf.d/
COPY *.py /etc/dd-agent/checks.d/
COPY pollev-entrypoint.sh /

# prepend our code that sets the redisdb.yaml for the current environment
# to the docker-dd-agent container's entrypoint.sh
RUN cat /entrypoint.sh >> /pollev-entrypoint.sh
RUN mv /pollev-entrypoint.sh /entrypoint.sh
