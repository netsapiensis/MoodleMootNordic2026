#!/usr/bin/env bash
# Runs at container start (the image's entrypoint runs /docker-entrypoint.d/*.sh):
# turns on Apache's ssl module and the https site, and turns off the plain-http one.
set -e
a2enmod -q ssl
a2ensite -q moodle-ssl
a2dissite -q 000-default
