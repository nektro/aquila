FROM alpine as golang
WORKDIR /app
COPY . .
ARG RELEASE_NUM
RUN apk add bash sudo wget curl jq git
RUN ./download_zig.sh 0.9.0-dev.946+6237dc0ab
RUN zigmod ci
RUN zig build -Dversion=r${RELEASE_NUM}

FROM alpine
COPY --from=golang /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=golang /app/zig-out/bin/aquila-zig /app/aquila
RUN apk add git

VOLUME /data
ENTRYPOINT ["/app/aquila", "--port", "8000", "--db", "/data/access.db"]
