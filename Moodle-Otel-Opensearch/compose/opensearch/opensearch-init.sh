#!/bin/bash
# Runs once, after OpenSearch is healthy: creates the user and the role that
# the OpenTelemetry Collector logs in with. This is step 7 of the talk
# ("Configure OpenSearch", row one), done through the security REST API
# instead of the Dashboards Security screens. Safe to re-run: PUT overwrites.
set -e
OS=https://opensearch:9200
CA=/usr/share/opensearch/config/certs/root-ca.pem
api() {
  curl -sS --fail-with-body --cacert "$CA" -u "admin:$OPENSEARCH_ADMIN_PASSWORD" \
    -H 'Content-Type: application/json' "$@"
  echo
}

# The role: create indices and write documents in the two index families the
# collector produces, plus the cluster-level right that manage_index_template
# needs. Nothing else, and no read access.
api -X PUT "$OS/_plugins/_security/api/roles/otel_collector" -d '{
  "cluster_permissions": ["cluster_manage_index_templates", "indices:data/write/bulk"],
  "index_permissions": [{
    "index_patterns": ["otel-v1-logs-*", "otel-v1-apm-span-*"],
    "allowed_actions": ["create_index", "write"]
  }]
}'

# The user, with the password otelcol-config.yaml holds.
api -X PUT "$OS/_plugins/_security/api/internalusers/otelcol" -d "{
  \"password\": \"$OTELCOL_PASSWORD\"
}"

# Map the user to the role.
api -X PUT "$OS/_plugins/_security/api/rolesmapping/otel_collector" -d '{
  "users": ["otelcol"]
}'
echo "opensearch-init: done"
