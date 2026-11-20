#!/bin/bash
set -e

source dev-container-features-test-lib

check "direnv is installed" command -v direnv
check "direnv runs" bash -c 'direnv version'
check "direnv emits a bash hook" bash -c 'direnv hook bash | grep -q _direnv_hook'
check "bash hook is configured in profile.d" grep -q 'direnv hook bash' /etc/profile.d/direnv.sh
check "bash hook is loaded in a login shell" bash -lc 'type _direnv_hook >/dev/null 2>&1'
check "fish hook is configured" test -f /etc/fish/conf.d/direnv.fish

reportResults
