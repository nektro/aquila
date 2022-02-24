FROM alpine as builder
WORKDIR /app
COPY ./bin/aquila-linux-x86_64 /app/aquila
RUN apk add git
RUN apk add wget tar unzip
RUN apk add mercurial
VOLUME /data
ENTRYPOINT ["/app/aquila", "--port", "8000", "--db", "/data/access.db"]
