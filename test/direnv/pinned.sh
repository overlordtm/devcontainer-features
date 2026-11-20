#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c '[ "$(direnv version)" = "2.38.2" ]'
check "shell hooks were skipped" test ! -f /etc/profile.d/direnv.sh

reportResults
