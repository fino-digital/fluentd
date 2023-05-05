FROM docker.io/bitnami/fluentd:1.16.1-debian-11-r0
ARG ES_VERSION=7.13.3
USER 0
RUN gem uninstall elasticsearch --force -x \
  && gem uninstall elasticsearch-api --force -x\
  && gem uninstall elastic-transport --force -x \
  && gem uninstall elasticsearch-xpack --force -x \ 
  && gem uninstall fluent-plugin-elasticsearch --force -x
RUN gem install elasticsearch -v ${ES_VERSION} \
  && gem install elasticsearch-api -v ${ES_VERSION} \
  && gem install elasticsearch-transport -v ${ES_VERSION} \
  && gem install elasticsearch-xpack -v ${ES_VERSION} \
  && gem install fluent-plugin-elasticsearch -v 4.3.3 \
  && gem install fluent-plugin-rewrite-tag-filter \
  && gem install fluent-plugin-multi-format-parser
RUN gem list | grep elastic
USER 1001
