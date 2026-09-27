#!/bin/bash
# Runs once, after OpenSearch Dashboards answers: loads the index pattern
# otel-v1-logs-* and the dashboard "Moodle events" with its six charts from
# moodle-dashboard.ndjson, makes the index pattern the default for Discover,
# and makes the dashboard the first page after login. Nobody has to build
# anything by hand. Safe to re-run: the import overwrites the same objects.
set -e
# The certificate names localhost, not opensearch-dashboards, so curl talks to
# localhost:5601 and --connect-to sends the connection to the Dashboards
# container. The certificate is still checked against the private CA.
DASH=https://localhost:5601
CA=/usr/share/opensearch/config/certs/root-ca.pem
api() {
  local rc=0
  curl -sS --fail-with-body --cacert "$CA" \
    --connect-to localhost:5601:opensearch-dashboards:5601 \
    -u "admin:$OPENSEARCH_ADMIN_PASSWORD" -H 'osd-xsrf: true' "$@" || rc=$?
  echo
  return $rc
}

# Dashboards has no health check in compose.yaml, so wait here until it
# answers, for at most five minutes.
for i in $(seq 1 60); do
  if api -o /dev/null "$DASH/api/status" 2>/dev/null; then break; fi
  if [ "$i" = 60 ]; then echo "dashboards-init: Dashboards did not answer"; exit 1; fi
  sleep 5
done

api -X POST "$DASH/api/saved_objects/_import?overwrite=true" \
  -F file=@/moodle-dashboard.ndjson

# Discover opens on the events, both pages show the last hour, and the first
# page after login is the dashboard.
api -X POST "$DASH/api/opensearch-dashboards/settings" \
  -H 'Content-Type: application/json' -d '{"changes": {
    "defaultIndex": "otel-v1-logs",
    "defaultRoute": "/app/dashboards#/view/moodle-events",
    "timepicker:timeDefaults": "{\"from\": \"now-1h\", \"to\": \"now\"}"
  }}'
echo "dashboards-init: done"
