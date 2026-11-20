#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/gcx
check "config directory exists" test -d /dc/gcx/config
check "persistent volume is writable" test -w /dc/gcx
check "onCreate script is installed and executable" test -x /usr/local/share/gcx-cli-persistence/oncreate.sh
check "~/.config/gcx is a symlink to the volume" bash -c '[ -L "${HOME}/.config/gcx" ] && [ "$(readlink "${HOME}/.config/gcx")" = "/dc/gcx/config" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.config/gcx/.persistence-check" && grep -q persistence-check /dc/gcx/config/.persistence-check'

reportResults
