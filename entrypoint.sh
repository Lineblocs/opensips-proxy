#!/bin/bash
: ${CLOUD=""} # One of aws, azure, do, gcp, or empty
if [ "$CLOUD" != "" ]; then
   PROVIDER="-provider ${CLOUD}"
fi

APP="sampo"
PRIVATE_IPV4=$(netdiscover -field privatev4 ${PROVIDER})
#PRIVATE_IPV4="172.24.0.1"
PUBLIC_IPV4=$(netdiscover -field publicv4 ${PROVIDER})
ADVERTIZED_IPV4="${PUBLIC_IPV4:-0.0.0.0}"

# change variables for cloud providers that use NAT. e.g AWS
if [ "$CLOUD" = "aws" ]; then
   PUBLIC_IPV4="${PRIVATE_IPV4:-127.0.0.1}"
fi

# todo add https support
API_SCHEME="http"
DEPLOYMENT_DOMAIN="${DEPLOYMENT_DOMAIN:-example.org}"
LINEBLOCS_KEY="${LINEBLOCS_KEY:-123xyz}"
API_URL="${API_SCHEME}://internals.${DEPLOYMENT_DOMAIN}"

echo "Public ipv4: ${PUBLIC_IPV4}"
echo "Private ipv4: ${PRIVATE_IPV4}"
echo "API URL: ${API_URL}"

CFG_PATH="/etc/opensips/opensips.cfg"

if [[ -z "${RTPPROXY_IPV4}" ]]; then
   #RTPPROXY_IPV4=${PUBLIC_IPV4}
   RTPPROXY_IPV4="127.0.0.1"
fi


echo "Updating configs with IPs"
# Set the IPs
sed "s/PRIVATE_IPV4/${PRIVATE_IPV4}/g" $CFG_PATH > $CFG_PATH.cop
sed "s/PUBLIC_IPV4/${PUBLIC_IPV4}/g" $CFG_PATH.cop > $CFG_PATH.cop2
sed "s/RTPPROXY_IPV4/${RTPPROXY_IPV4}/g" $CFG_PATH.cop2 > $CFG_PATH.final

rm -rf $CFG_PATH.cop*
yes|mv  $CFG_PATH.final $CFG_PATH

DB_USER="${DB_USER:-empty}"
DB_PASS="${DB_PASS:-empty}"
DB_HOST="${DB_HOST:-empty}"
DB_NAME="${DB_NAME:-empty}"
DB_OPENSIPS="${DB_OPENSIPS:-empty}"
LINEBLOCS_KEY="${LINEBLOCS_KEY:-empty}"

echo "Updating database variables"
# Change the DB info
sed "s/DB_USER/${DB_USER}/g" $CFG_PATH > $CFG_PATH.cop
sed "s/DB_PASS/${DB_PASS}/g" $CFG_PATH.cop > $CFG_PATH.cop2
sed "s/DB_HOST/${DB_HOST}/g" $CFG_PATH.cop2 > $CFG_PATH.cop3
sed "s/DB_NAME/${DB_NAME}/g" $CFG_PATH.cop3 > $CFG_PATH.cop4
sed "s/DB_OPENSIPS/${DB_OPENSIPS}/g" $CFG_PATH.cop4 > $CFG_PATH.cop5


echo "Changing API URLs"
# change API URLs
# use alternative delimiter for API_URL as it contains slashes
# for example: sed "s~$var~replace~g" $file
sed "s~API_URL~${API_URL}~g" $CFG_PATH.cop5 > $CFG_PATH.final

rm -rf $CFG_PATH.cop*
yes|mv  $CFG_PATH.final $CFG_PATH

# Set the Lineblocs key 
echo "Configuring Lineblocs key"
sed "s/LINEBLOCS_KEY/${LINEBLOCS_KEY}/g" $CFG_PATH > $CFG_PATH.cop
cp $CFG_PATH.cop $CFG_PATH.final

rm -rf $CFG_PATH.cop*
yes|mv  $CFG_PATH.final $CFG_PATH

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