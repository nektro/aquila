FROM alpine
USER root
WORKDIR /app
RUN apk add git
RUN apk add wget tar unzip
RUN apk add mercurial
RUN apk add openssh-client
VOLUME /data
VOLUME /images
COPY ./docs/etc/id_rsa /root/.ssh/id_rsa
COPY ./docs/etc/id_rsa.pub /root/.ssh/id_rsa.pub
COPY ./bin/aquila-linux-x86_64 /app/aquila
ENTRYPOINT ["/app/aquila", "--port", "8000", "--db", "/data/access.db"]
