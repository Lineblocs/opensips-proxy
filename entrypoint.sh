#!/bin/bash
: ${CLOUD=""} # One of aws, azure, do, gcp, or empty
if [ "$CLOUD" != "" ]; then
   PROVIDER="-provider ${CLOUD}"
fi

# NOTE: variables below which are exported are used in envsubst and probably not defined beforehand. If you wish to pass
# another one, TLS_ENABLED for example, and it has not been defined before in the docker run command, you need to export
# it to make it available in subcommands (ie. envsubst).

APP="sampo"
#PRIVATE_IPV4=$(netdiscover -field privatev4 ${PROVIDER})
export  PRIVATE_IPV4="172.24.0.1"
#PUBLIC_IPV4=$(netdiscover -field publicv4 ${PROVIDER})
export  PUBLIC_IPV4="10.9.0.5"
ADVERTIZED_IPV4="${PUBLIC_IPV4:-0.0.0.0}"

# change variables for cloud providers that use NAT. e.g AWS
if [ "$CLOUD" = "aws" ]; then
   #PUBLIC_IPV4="${PRIVATE_IPV4:-127.0.0.1}"
   PUBLIC_IPV4="0.0.0.0"
fi

# todo add https support
API_SCHEME="http"
DEPLOYMENT_DOMAIN="${DEPLOYMENT_DOMAIN:-example.org}"
export LINEBLOCS_KEY="${LINEBLOCS_KEY:-123xyz}"
export API_URL="${API_SCHEME}://internals.${DEPLOYMENT_DOMAIN}"

echo "Public ipv4: ${PUBLIC_IPV4}"
echo "Private ipv4: ${PRIVATE_IPV4}"
echo "API URL: ${API_URL}"

CFG_PATH="/etc/opensips/opensips.cfg"

if [[ -z "${RTPPROXY_IPV4}" ]]; then
   #RTPPROXY_IPV4=${PUBLIC_IPV4}
   export RTPPROXY_IPV4="127.0.0.1"
fi

export DB_USER="${DB_USER:-empty}"
export DB_PASS="${DB_PASS:-empty}"
export DB_HOST="${DB_HOST:-empty}"
export DB_NAME="${DB_NAME:-empty}"
export DB_OPENSIPS="${DB_OPENSIPS:-empty}"


cp $CFG_PATH $CFG_PATH.temp
envsubst '$PRIVATE_IPV4 $PUBLIC_IPV4 $RTPPROXY_IPV4 $DB_USER $DB_PASS $DB_HOME $DB_NAME $DB_OPENSIPS $DB_USER $API_URL $LINEBLOCS_KEY' < $CFG_PATH.temp > $CFG_PATH
rm -rf $CFG_PATH.temp

echo "Final opensips.cfg contents are"
cat $CFG_PATH
echo ""

OPENSIPS_ARGS="-FE"
# run sampo API server in background
echo "Starting sampo API server"
socat -d TCP-LISTEN:1042,reuseaddr,fork,pf=ip4 \
                    exec:/${APP}/${APP}.sh &


echo "Waiting for RTPproxies to be up before starting OpenSIPs.."

sleep 30;

# start opensips server
/usr/sbin/opensips ${OPENSIPS_ARGS}