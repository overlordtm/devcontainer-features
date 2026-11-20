#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/aws
check "config directory exists" test -d /dc/aws/config
check "persistent volume is writable" test -w /dc/aws
check "onCreate script is installed and executable" test -x /usr/local/share/aws-cli-persistence/oncreate.sh
check "~/.aws is a symlink to the volume" bash -c '[ -L "${HOME}/.aws" ] && [ "$(readlink "${HOME}/.aws")" = "/dc/aws/config" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.aws/.persistence-check" && grep -q persistence-check /dc/aws/config/.persistence-check'

reportResults
