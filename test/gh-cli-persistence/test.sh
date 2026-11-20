#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/gh
check "config directory exists" test -d /dc/gh/config
check "data directory exists" test -d /dc/gh/data
check "state directory exists" test -d /dc/gh/state
check "persistent volume is writable" test -w /dc/gh
check "onCreate script is installed and executable" test -x /usr/local/share/gh-cli-persistence/oncreate.sh
check "~/.config/gh is a symlink to the volume" bash -c '[ -L "${HOME}/.config/gh" ] && [ "$(readlink "${HOME}/.config/gh")" = "/dc/gh/config" ]'
check "~/.local/share/gh is a symlink to the volume" bash -c '[ -L "${HOME}/.local/share/gh" ] && [ "$(readlink "${HOME}/.local/share/gh")" = "/dc/gh/data" ]'
check "~/.local/state/gh is a symlink to the volume" bash -c '[ -L "${HOME}/.local/state/gh" ] && [ "$(readlink "${HOME}/.local/state/gh")" = "/dc/gh/state" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.config/gh/.persistence-check" && grep -q persistence-check /dc/gh/config/.persistence-check'

reportResults
