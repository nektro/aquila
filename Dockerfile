FROM golang:alpine as golang
WORKDIR /app
COPY . .
ARG BUILD_NUM
RUN ./docker_build.sh

FROM alpine
COPY --from=golang /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=golang /app/zigmod /bin/zigmod
COPY --from=golang /app/aquila /app/aquila
RUN apk add --no-cache git

VOLUME /data
ENTRYPOINT ["/app/aquila", "--port", "8000", "--config", "/data/config.json"]
