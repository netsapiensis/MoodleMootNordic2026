#!/usr/bin/env bash
# One-shot: prepare moodledata and install the Moodle database once.
set -euo pipefail
cd /var/www/html

chown -R www-data:www-data /var/www/moodledata

if [ -f /var/www/moodledata/.installed ]; then
    echo "moodle-init: already installed, nothing to do"
    exit 0
fi

echo "moodle-init: installing the Moodle database (takes a minute or two)"
su -s /bin/bash www-data -c "php admin/cli/install_database.php \
    --agree-license \
    --adminpass='DemoAdmin2026!' \
    --adminemail='admin@example.com' \
    --fullname='Moodle OpenTelemetry demo' \
    --shortname='otel-demo'"

touch /var/www/moodledata/.installed
echo "moodle-init: done. Log in at https://localhost as admin / DemoAdmin2026!"
