FROM perl:latest
LABEL maintainer="dave@perlhacks.com"

EXPOSE 8080
CMD carton exec starman --port 8080 Feeds/bin/app.psgi

RUN cpanm Carton Starman

COPY . /feeds
RUN cd /feeds && carton install --deployment
WORKDIR /feeds
