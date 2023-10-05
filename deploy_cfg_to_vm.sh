#!/bin/bash
: ${CLOUD=""} # One of aws, azure, do, gcp, or empty
if [ "$CLOUD" != "" ]; then
   PROVIDER="-provider ${CLOUD}"
fi

# NOTE: variables below which are exported are used in envsubst and probably not defined beforehand. If you wish to pass
# another one, TLS_ENABLED for example, and it has not been defined before in the docker run command, you need to export
# it to make it available in subcommands (ie. envsubst).

APP="sampo"
export PRIVATE_IPV4=$(netdiscover -field privatev4 ${PROVIDER})
export PUBLIC_IPV4=$(netdiscover -field publicv4 ${PROVIDER})
export ADVERTIZED_IPV4="${PUBLIC_IPV4:-0.0.0.0}"

# change variables for cloud providers that use NAT. e.g AWS
if [ "$CLOUD" = "aws" ]; then
   #PUBLIC_IPV4="${PRIVATE_IPV4:-127.0.0.1}"
   PUBLIC_IPV4="0.0.0.0"
fi

# todo add https support
API_SCHEME="http"
#DEPLOYMENT_DOMAIN="${DEPLOYMENT_DOMAIN:-example.org}"
DEPLOYMENT_DOMAIN="lineblocs.com"
export LINEBLOCS_KEY="${LINEBLOCS_KEY:-123xyz}"
export API_URL="${API_SCHEME}://internals.${DEPLOYMENT_DOMAIN}"

echo "Public ipv4: ${PUBLIC_IPV4}"
echo "Private ipv4: ${PRIVATE_IPV4}"
echo "API URL: ${API_URL}"

CFG_PATH="./configs/opensips.cfg"
DEPLOY_CFG_PATH="/etc/opensips/opensips.cfg"

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
envsubst '$PRIVATE_IPV4 $PUBLIC_IPV4 $RTPPROXY_IPV4 $DB_USER $DB_PASS $DB_HOST $DB_NAME $DB_OPENSIPS $DB_USER $API_URL $LINEBLOCS_KEY $DEPLOYMENT_DOMAIN' < $CFG_PATH.temp > $DEPLOY_CFG_PATH
# make database modifications with Python scripts
echo "Adding OpenSIPs customization parameters (this may take some time)"
./create_opensips_cfg

rm -rf $CFG_PATH.temp

echo "Final opensips.cfg contents are"
cat $CFG_PATH
echo ""

echo "Updated OpenSIPs config successfully"