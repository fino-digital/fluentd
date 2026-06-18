# Custom Fluentd image for fino, shipping logs to Sematext.
# Base: upstream, maintained fluent/fluentd (we left the now-frozen
# bitnamilegacy/fluentd base). apt-get upgrade + the gem refresh below pull the
# latest Debian and Ruby stdlib CVE fixes at build time, so a plain rebuild
# (re-tag) picks up security patches without a base bump.
FROM fluent/fluentd:v1.19-debian-2

# elasticsearch (client) and fluent-plugin-elasticsearch are intentionally
# pinned: these versions are known to talk to the Sematext logsene receiver
# correctly. Do NOT bump without validating ingestion against Sematext first
# (newer fluent-plugin-elasticsearch / ES 8.x clients change the bulk API
# handshake). If a vuln scan flags them, validate a bump on a test index.
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

# Keep the /opt/bitnami directory layout so this image is a drop-in for the
# deployment that replaced the Bitnami chart: the vendored manifests still
# mount the config at /opt/bitnami/fluentd/conf and write buffers under
# /opt/bitnami/fluentd/logs/buffers. The symlink makes the upstream entrypoint's
# `fluentd -c /fluentd/etc/${FLUENTD_CONF}` resolve into the mounted configmap.
# (Moving to a plain /fluentd layout means changing those mounts in lockstep.)
RUN mkdir -p /opt/bitnami/fluentd/conf /opt/bitnami/fluentd/logs/buffers \
  && rm -rf /fluentd/etc \
  && ln -s /opt/bitnami/fluentd/conf /fluentd/etc \
  && chown -R fluent:fluent /opt/bitnami /fluentd

RUN gem list | grep -E 'elastic|fluent-plugin'

USER 1001
