#!/bin/bash
set -e

source dev-container-features-test-lib

check "gcx environment profile was not written" test ! -f /etc/profile.d/gcx.sh
check "no keychain override in /etc/environment" bash -c '! grep -q "^GCX_KEYCHAIN=" /etc/environment'
check "no telemetry override in /etc/environment" bash -c '! grep -q "^GCX_TELEMETRY=" /etc/environment'

reportResults
