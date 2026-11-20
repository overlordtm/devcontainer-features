#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent config directory exists" test -d /dc/opencode
check "config directory exists" test -d /dc/opencode/config
check "data directory exists" test -d /dc/opencode/data
check "state directory exists" test -d /dc/opencode/state
check "persistent volume is writable" test -w /dc/opencode
check "onCreate script is installed and executable" test -x /usr/local/share/opencode-persistence/oncreate.sh
check "~/.config/opencode is a symlink to the volume" bash -c '[ -L "${HOME}/.config/opencode" ] && [ "$(readlink "${HOME}/.config/opencode")" = "/dc/opencode/config" ]'
check "~/.local/share/opencode is a symlink to the volume" bash -c '[ -L "${HOME}/.local/share/opencode" ] && [ "$(readlink "${HOME}/.local/share/opencode")" = "/dc/opencode/data" ]'
check "~/.local/state/opencode is a symlink to the volume" bash -c '[ -L "${HOME}/.local/state/opencode" ] && [ "$(readlink "${HOME}/.local/state/opencode")" = "/dc/opencode/state" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.local/share/opencode/.persistence-check" && grep -q persistence-check /dc/opencode/data/.persistence-check'

reportResults
