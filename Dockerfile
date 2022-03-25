FROM alpine:3.15.1

RUN \
  apk update && \
  apk add openssl && \
  rm -rf /var/cache/apk/*

ADD crypto* /usr/bin/

ENTRYPOINT ["/usr/bin/crypto"]
