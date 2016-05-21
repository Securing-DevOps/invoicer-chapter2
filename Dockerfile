FROM busybox:1.24.2

WORKDIR /app

RUN addgroup -g 10001 app && \
    adduser -G app -u 10001 -D -h /app -s /sbin/nologin app

COPY bin/invoicer /bin/invoicer

USER app

EXPOSE 8080
ENTRYPOINT /bin/invoicer
