#!/usr/bin/env bash
set -e
set -u
set -o pipefail

echo "Reloading RTP proxies"
opensips-cli -x mi rtpengine_reload