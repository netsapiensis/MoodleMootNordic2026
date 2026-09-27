#!/bin/sh
# Generates the self-signed certificates for the demo stack, once, into
# ./certs (bind-mounted at /certs). Runs in the alpine/openssl image.
#   root-ca.pem            the private CA; give this to curl with --cacert
#   node.pem, node-key.pem OpenSearch's server certificate (also used by
#                          OpenSearch Dashboards for https on port 5601)
#   admin.pem, admin-key.pem  a client certificate matching admin_dn, for
#                          plugins/opensearch-security/tools/securityadmin.sh
set -e
cd /certs
if [ -f root-ca.pem ] && [ -f node.pem ] && [ -f admin.pem ]; then
  echo "make-certs: certificates already exist, nothing to do"
  exit 0
fi
O=moodle-otel-demo
DAYS=3650

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out root-ca-key.pem
openssl req -x509 -new -key root-ca-key.pem -days $DAYS \
  -subj "/O=$O/CN=$O root CA" -out root-ca.pem

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out node-key.pem
openssl req -new -key node-key.pem -subj "/O=$O/CN=opensearch" -out node.csr
printf 'subjectAltName=DNS:opensearch,DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth,clientAuth\n' > node.ext
openssl x509 -req -in node.csr -CA root-ca.pem -CAkey root-ca-key.pem \
  -CAcreateserial -days $DAYS -extfile node.ext -out node.pem

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out admin-key.pem
openssl req -new -key admin-key.pem -subj "/O=$O/CN=admin" -out admin.csr
printf 'extendedKeyUsage=clientAuth\n' > admin.ext
openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem \
  -CAcreateserial -days $DAYS -extfile admin.ext -out admin.pem

rm -f node.csr node.ext admin.csr admin.ext root-ca.srl
# OpenSearch and OpenSearch Dashboards run as uid 1000 and must read the keys.
chown 1000:1000 ./*.pem
chmod 644 root-ca.pem node.pem admin.pem
chmod 640 root-ca-key.pem node-key.pem admin-key.pem
echo "make-certs: done"
ls -l /certs
