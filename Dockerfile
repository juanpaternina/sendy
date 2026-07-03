#
# Docker with Sendy Email Campaign Marketing
#
# Build:
# $ docker build -t sendy:latest --target sendy -f ./Dockerfile .
#
# Build w/ XDEBUG installed
# $ docker build -t sendy:debug-latest --target debug -f ./Dockerfile .
#
# Run:
# $ docker run --rm -d --env-file sendy.env sendy:latest

FROM php:8.0-apache AS sendy

ARG SENDY_VER=7.0.6
ARG ARTIFACT_DIR=7.0.6

ENV SENDY_VERSION=${SENDY_VER}

RUN apt -qq update && apt -qq upgrade -y \
  # Install unzip cron
  && apt -qq install -y --no-install-recommends unzip cron \
  # Install php extension gettext
  # Install php extension mysqli
  && docker-php-ext-install calendar gettext mysqli \
  # Remove unused packages and apt caches
  && apt autoremove -y \
  && apt clean \
  && rm -rf /var/lib/apt/lists/*

# Install Sendy (artifacts are bind-mounted at build time; no COPY layer)
RUN --mount=type=bind,source=artifacts/${ARTIFACT_DIR},target=/artifacts \
  unzip -q /artifacts/sendy-${SENDY_VER}.zip -d /tmp \
  && cp -r /artifacts/includes/* /tmp/sendy/includes \
  && mkdir -p /tmp/sendy/uploads/csvs \
  && chmod -R 777 /tmp/sendy/uploads \
  && rm -rf /var/www/html \
  && mv /tmp/sendy /var/www/html \
  && chown -R www-data:www-data /var/www \
  && mv /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini \
  && rm -rf /tmp/* \
  && echo "\nServerName \${SENDY_FQDN}" > /etc/apache2/conf-available/serverName.conf \
  # Ensure X-Powered-By is always removed regardless of php.ini or other settings.
  && printf "\n\n# Ensure X-Powered-By is always removed regardless of php.ini or other settings.\n\
  Header always unset \"X-Powered-By\"\n\
  Header unset \"X-Powered-By\"\n" >> /var/www/html/.htaccess \
  && printf "[PHP]\nerror_reporting = E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED\n" > /usr/local/etc/php/conf.d/error_reporting.ini

# Apache config and modules
RUN a2enconf serverName && a2enmod rewrite headers

# Copy hello-cron file to the cron.d directory
COPY cron /etc/cron.d/cron
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/cron \
  # Apply cron job
  && crontab /etc/cron.d/cron \
  # Create the log file to be able to run tail
  && touch /var/log/cron.log

COPY artifacts/docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]

#######################
# XDEBUG Installation
#######################
FROM sendy AS debug
# Install xdebug extension
RUN pecl channel-update pecl.php.net \
  && pecl install xdebug \
  && docker-php-ext-enable xdebug \
  && rm -rf /tmp/pear 


