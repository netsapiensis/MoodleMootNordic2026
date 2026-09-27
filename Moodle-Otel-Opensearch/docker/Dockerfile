# Moodle 5.2 with OpenTelemetry, for the sysadmin presentation demo.
#
# This image is boxes 1-4 of the chain in one place:
#   1. Moodle 5.2 source
#   2. ext-opentelemetry            (PECL, C extension)
#   3. moodlehq/moodle-package-otel (Composer)
#   4. open-telemetry/sdk + exporter-otlp (Composer, pulled in as deps)
#
# Everything is baked in at build time so a pod restart cannot lose it.

FROM docker.io/moodlehq/moodle-php-apache:8.3

ARG MOODLE_BRANCH=MOODLE_502_STABLE

# Build tools for the PECL compile, plus git for the Moodle clone.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git unzip \
    && rm -rf /var/lib/apt/lists/*

# --- box 2: the PHP extension -------------------------------------------
# `yes ''` answers the interactive "enable opentelemetry support?" prompt.
RUN yes '' | pecl install opentelemetry \
    && printf '[opentelemetry]\nextension=opentelemetry.so\n' \
         > /usr/local/etc/php/conf.d/opentelemetry.ini \
    && php --ri opentelemetry

# --- Composer itself ----------------------------------------------------
COPY --from=docker.io/composer:2 /usr/bin/composer /usr/local/bin/composer

# --- box 1: Moodle 5.2 --------------------------------------------------
RUN git clone --branch "${MOODLE_BRANCH}" --depth 1 \
        https://github.com/moodle/moodle.git /var/www/html \
    && rm -rf /var/www/html/.git

WORKDIR /var/www/html

# --- boxes 3 and 4: the Composer packages -------------------------------
RUN composer require --no-interaction --no-progress --no-audit \
        moodlehq/moodle-package-otel \
        open-telemetry/exporter-otlp \
    && composer dump-autoload --no-interaction \
    && chown -R www-data:www-data /var/www/html/vendor

# The base image reads this at start-up and writes the Apache DocumentRoot.
# Moodle 5.2 serves from public/, not from the project root.
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
