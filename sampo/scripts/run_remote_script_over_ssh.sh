#!/usr/bin/env bash
set -e
set -u
set -o pipefail
readonly remote_host="$1"
readonly script_to_run="$2"

# shellcheck disable=SC2029
ssh "$remote_host" "$script_to_run"