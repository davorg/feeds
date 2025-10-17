FROM perl:5.42.0
LABEL maintainer="dave@davecross.co.uk"

# Faster builds: cache CPAN deps based on cpanfile
WORKDIR /app
COPY cpanfile /app/
RUN cpanm --notest --installdeps .

# App code (after deps for better cache hits)
COPY . /app

# Ensure Starman + HTTPS protocol (in case not in cpanfile)
RUN cpanm --notest Starman LWP::Protocol::https

# Prod env
ENV PLACK_ENV=production

# Use a non-root user
RUN adduser --disabled-password --gecos "" appuser \
 && chown -R appuser:appuser /app
USER appuser

# Cloud Run default is 8080; honour $PORT
EXPOSE 8080
CMD ["sh","-lc","exec starman --listen :${PORT:-8080} --workers ${WORKERS:-2} --preload-app Feeds/bin/app.psgi"]

