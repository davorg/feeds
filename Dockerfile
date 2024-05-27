FROM perl:5.38.0
LABEL maintainer="dave@perlhacks.org"

EXPOSE 5000
CMD starman Feeds/bin/app.psgi

COPY . /feeds
RUN cd /feeds && cpanm Starman LWP::Protocol::https && cpanm --installdeps .
WORKDIR /feeds
