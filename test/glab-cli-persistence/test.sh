#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/glab
check "config directory exists" test -d /dc/glab/config
check "persistent volume is writable" test -w /dc/glab
check "onCreate script is installed and executable" test -x /usr/local/share/glab-cli-persistence/oncreate.sh
check "~/.config/glab-cli is a symlink to the volume" bash -c '[ -L "${HOME}/.config/glab-cli" ] && [ "$(readlink "${HOME}/.config/glab-cli")" = "/dc/glab/config" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.config/glab-cli/.persistence-check" && grep -q persistence-check /dc/glab/config/.persistence-check'

reportResults
