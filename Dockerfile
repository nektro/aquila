FROM alpine as builder
WORKDIR /app
COPY ./bin/aquila-linux-x86_64 /app/aquila
RUN apk add git
VOLUME /data
ENTRYPOINT ["/app/aquila", "--port", "8000", "--db", "/data/access.db"]
