FROM fluent/fluentd:v1.19-debian-2

ARG ES_VERSION=7.13.3

USER 0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
  && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y --no-install-recommends build-essential libffi-dev libssl-dev \
  && gem update erb net-imap rdoc rexml cgi \
  && gem install elasticsearch -v ${ES_VERSION} \
  && gem install elasticsearch-api -v ${ES_VERSION} \
  && gem install elasticsearch-transport -v ${ES_VERSION} \
  && gem install elasticsearch-xpack -v ${ES_VERSION} \
  && gem install fluent-plugin-elasticsearch -v 4.3.3 \
  && gem install fluent-plugin-s3 \
  && gem install fluent-plugin-rewrite-tag-filter \
  && gem install fluent-plugin-record-modifier \
  && gem install fluent-plugin-concat \
  && gem install fluent-plugin-kubernetes_metadata_filter \
  && gem install fluent-plugin-prometheus \
  && gem install fluent-plugin-anonymizer \
  && apt-get purge -y --auto-remove build-essential libffi-dev libssl-dev \
  && rm -rf /var/lib/apt/lists/* /usr/local/bundle/cache/*

# Match the directory layout the Bitnami Fluentd Helm chart mounts into,
# and point the upstream entrypoint's default config dir at it so
# `--config /fluentd/etc/${FLUENTD_CONF}` resolves into the mounted configmap.
RUN mkdir -p /opt/bitnami/fluentd/conf /opt/bitnami/fluentd/logs/buffers \
  && rm -rf /fluentd/etc \
  && ln -s /opt/bitnami/fluentd/conf /fluentd/etc \
  && chown -R fluent:fluent /opt/bitnami /fluentd

RUN gem list | grep -E 'elastic|fluent-plugin'

USER 1001
