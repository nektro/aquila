FROM alpine
WORKDIR /app
RUN apk add git
RUN apk add wget tar unzip
RUN apk add mercurial
VOLUME /data
COPY ./bin/aquila-linux-x86_64 /app/aquila
ENTRYPOINT ["/app/aquila", "--port", "8000", "--db", "/data/access.db"]
