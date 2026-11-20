#!/bin/bash
set -e

source dev-container-features-test-lib

check "claude is installed" command -v claude
check "claude runs" bash -c 'claude --version | grep -Eq "^[0-9]+\.[0-9]+\.[0-9]+"'
check "auto-updates are disabled" test "${DISABLE_AUTOUPDATER}" = "1"

reportResults
