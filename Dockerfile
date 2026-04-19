FROM docker.io/bitnamilegacy/fluentd:1.19.0-debian-12-r2
ARG ES_VERSION=7.13.3
USER 0
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN gem update --system 3.5.14 \
  && gem uninstall elasticsearch --force -x \
  && gem uninstall elasticsearch-api --force -x\
  && gem uninstall elastic-transport --force -x \
  && gem uninstall elasticsearch-xpack --force -x \ 
  && gem uninstall fluent-plugin-elasticsearch --force -x \
  && gem uninstall json --force -x
RUN gem install elasticsearch -v ${ES_VERSION} \
  && gem install elasticsearch-api -v ${ES_VERSION} \
  && gem install elasticsearch-transport -v ${ES_VERSION} \
  && gem install elasticsearch-xpack -v ${ES_VERSION} \
  && gem install fluent-plugin-anonymizer -v 1.0.0 \
  && gem install fluent-plugin-elasticsearch -v 4.3.3 \
  && gem install fluent-plugin-rewrite-tag-filter \
  && gem install fluent-plugin-multi-format-parser
RUN gem list | grep -E 'elastic|json'
USER 1001
