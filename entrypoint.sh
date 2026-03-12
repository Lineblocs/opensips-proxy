#!/bin/bash
: ${CLOUD=""} # One of aws, azure, do, gcp, or empty
if [ "$CLOUD" != "" ]; then
   PROVIDER="-provider ${CLOUD}"
fi

# --- NEW: Setup Logging Permissions ---
usermod -a -G tty syslog
service rsyslog start
cron
# --------------------------------------

APP="sampo"
export PRIVATE_IPV4=$(netdiscover -field privatev4 ${PROVIDER})
export PUBLIC_IPV4=$(netdiscover -field publicv4 ${PROVIDER})
export ADVERTIZED_IPV4="${PUBLIC_IPV4:-0.0.0.0}"

if [ "$CLOUD" = "aws" ]; then
   PUBLIC_IPV4="0.0.0.0"
fi

API_SCHEME="http"
DEPLOYMENT_DOMAIN="${DEPLOYMENT_DOMAIN:-example.org}"
export LINEBLOCS_KEY="${LINEBLOCS_KEY:-123xyz}"
if [[ -z "${API_URL}" ]]; then
   export API_URL="${API_SCHEME}://internals.${DEPLOYMENT_DOMAIN}"
fi

if [[ -z "${CARRIER_KEY}" ]]; then
   echo "no carrier key is setup, so it will be created automatically"
fi

echo "Public ipv4: ${PUBLIC_IPV4}"
echo "Private ipv4: ${PRIVATE_IPV4}"
echo "API URL: ${API_URL}"

CFG_PATH="/etc/opensips/opensips.cfg"

if [[ -z "${RTPPROXY_IPV4}" ]]; then
   export RTPPROXY_IPV4="127.0.0.1"
fi

export DB_USER="${DB_USER:-empty}"
export DB_PASS="${DB_PASS:-empty}"
export DB_HOST="${DB_HOST:-empty}"
export DB_NAME="${DB_NAME:-empty}"
export DB_OPENSIPS="${DB_OPENSIPS:-empty}"

echo "Adding OpenSIPs customization parameters (this may take some time)"
./create_opensips_cfg

rm -rf $CFG_PATH.temp

OPENSIPS_ARGS="-F -m 512"

# run sampo API server in background
echo "Starting sampo API server"
socat -d TCP-LISTEN:1042,reuseaddr,fork,pf=ip4 \
                    exec:/${APP}/${APP}.sh &

# start opensips server
# Note: Ensure log_facility = LOG_LOCAL0; is in opensips.cfg
/usr/sbin/opensips ${OPENSIPS_ARGS}