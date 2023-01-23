FROM perl:latest
LABEL maintainer="dave@perlhacks.com"

EXPOSE 8080
CMD plackup -s Starman -p 8080 Feeds/bin/app.psgi

COPY . /feeds
RUN cd /feeds && cpanm --notest --installdeps .
WORKDIR /feeds
