# Custom Fluentd image for fino, shipping logs to Sematext.
# Base: upstream, maintained fluent/fluentd (we left the now-frozen
# bitnamilegacy/fluentd base). Pinned by digest for reproducibility; apt-get
# upgrade still pulls the latest Debian CVE fixes at build time. Bump the digest
# (and the gem pins below) by rebuilding against a newer base periodically.
FROM fluent/fluentd:v1.19-debian-2@sha256:2d24ed0601b054e88df77a850ed9bc5a35fab3a58a6a7d7aa70258ee51037050

LABEL org.opencontainers.image.source="https://github.com/fino-digital/fluentd" \
      org.opencontainers.image.description="fino custom Fluentd (Sematext output) on upstream fluent/fluentd" \
      org.opencontainers.image.licenses="Apache-2.0"

# elasticsearch (client) and fluent-plugin-elasticsearch are intentionally
# pinned: these versions are known to talk to the Sematext logsene receiver
# correctly. Do NOT bump without validating ingestion against Sematext first
# (newer fluent-plugin-elasticsearch / ES 8.x clients change the bulk API
# handshake). If a vuln scan flags them, validate a bump on a test index.
ARG ES_VERSION=7.13.3

USER 0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# All gems are pinned for reproducible builds.
RUN apt-get update \
  && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y --no-install-recommends build-essential libffi-dev libssl-dev \
  && gem install erb -v 6.0.4 \
  && gem install elasticsearch -v ${ES_VERSION} \
  && gem install elasticsearch-api -v ${ES_VERSION} \
  && gem install elasticsearch-transport -v ${ES_VERSION} \
  && gem install elasticsearch-xpack -v ${ES_VERSION} \
  && gem install fluent-plugin-elasticsearch -v 4.3.3 \
  && gem install fluent-plugin-s3 -v 1.8.4 \
  && gem install fluent-plugin-rewrite-tag-filter -v 2.4.0 \
  && gem install fluent-plugin-record-modifier -v 2.2.1 \
  && gem install fluent-plugin-concat -v 2.6.2 \
  && gem install fluent-plugin-kubernetes_metadata_filter -v 3.8.0 \
  && gem install fluent-plugin-prometheus -v 2.2.2 \
  && gem install fluent-plugin-anonymizer -v 1.0.0 \
  && apt-get purge -y --auto-remove build-essential libffi-dev libssl-dev \
  && rm -rf /var/lib/apt/lists/* /usr/local/bundle/cache/*

# erb and net-imap are Ruby *default* gems baked into the base: gem install /
# gem uninstall leaves the original default gemspec on disk, so scanners (and
# Ruby) still see the vulnerable version. Drop the default specs explicitly.
# - erb: keep it (fluentd needs it) but force the installed, CVE-fixed 6.0.4 by
#   removing the vulnerable default gemspec.
# - net-imap: remove it entirely (default gemspec + lib). Nothing in our pipeline
#   does IMAP, and it is a recurring CVE source, so dropping it shrinks surface.
RUN DEFAULT_SPECS="$(ruby -e 'print Gem.default_specifications_dir')" \
  && RUBYLIB_DIR="$(ruby -e 'print RbConfig::CONFIG["rubylibdir"]')" \
  && rm -f "$DEFAULT_SPECS"/erb-*.gemspec "$DEFAULT_SPECS"/net-imap-*.gemspec \
  && rm -rf "$RUBYLIB_DIR"/net/imap.rb "$RUBYLIB_DIR"/net/imap

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

# Show the installed plugin/es gems, confirm the fixed erb still loads, and that
# net-imap is gone (fail the build if it lingers).
RUN gem list | grep -E 'elastic|fluent-plugin' \
  && gem list -e erb \
  && ruby -e "require 'erb'; ERB.new('ok')" \
  && { gem list -e net-imap | grep -qi '^net-imap ' && { echo "ERROR: net-imap still present"; exit 1; } || echo "net-imap removed"; } \
  && { ruby -e "require 'net/imap'" 2>/dev/null && { echo "ERROR: net/imap still loadable"; exit 1; } || echo "net/imap not loadable"; }

USER 1001
