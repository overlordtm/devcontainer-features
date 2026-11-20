#!/bin/bash
set -e

source dev-container-features-test-lib

check "gcx is installed" command -v gcx
check "gcx runs" bash -c 'gcx --version | grep -q "^gcx version "'
check "default version is pinned" bash -c 'gcx --version | grep -q "gcx version 1.8.0"'
check "keychain is disabled by default" grep -q '^export GCX_KEYCHAIN=off$' /etc/profile.d/gcx.sh
check "telemetry is disabled by default" grep -q '^export GCX_TELEMETRY=disabled$' /etc/profile.d/gcx.sh
check "gcx environment is present in a login shell" bash -lc '[ "${GCX_KEYCHAIN}" = "off" ] && [ "${GCX_TELEMETRY}" = "disabled" ]'
check "keychain default is written to /etc/environment" grep -q '^GCX_KEYCHAIN=off$' /etc/environment
check "telemetry default is written to /etc/environment" grep -q '^GCX_TELEMETRY=disabled$' /etc/environment

reportResults
