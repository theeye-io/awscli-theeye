FROM alpine:edge

ARG BUILD_DATE
ARG VCS_REF

LABEL org.label-schema.build-date=$BUILD_DATE\
      org.label-schema.vcs-url="https://github.com/theeye-io-team/awscli-theeye.git"\
      org.label-schema.vcs-ref=$VCS_REF\
      org.label-schema.name="AWS CLI And Theeye-Agent"\
      org.label-schema.usage="https://github.com/theeye-io-team/awscli-theeye#oneshot-docker-run"\
      org.label-schema.schema-version="1.0.0-rc.1"

RUN addgroup -S aws && adduser -S -G aws aws
RUN apk --no-cache add jq bash
RUN set -x\
 && apk --no-cache add --virtual .build-deps\
  py2-pip\
  py-setuptools\
 && apk --no-cache add\
  groff\
  less\
  python2\
 && pip --no-cache-dir install awscli\
 && apk del .build-deps\
 && rm -rf /var/cache/apk/*


WORKDIR /src
COPY . /src
RUN chmod 777 /src/scripts/*
USER aws

#ENTRYPOINT ["aws"]
CMD ["aws help"]
