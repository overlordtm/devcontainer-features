#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/fj
check "config directory exists" test -d /dc/fj/config
check "data directory exists" test -d /dc/fj/data
check "persistent volume is writable" test -w /dc/fj
check "onCreate script is installed and executable" test -x /usr/local/share/fj-cli-persistence/oncreate.sh
check "~/.local/share/forgejo-cli is a symlink to the volume" bash -c '[ -L "${HOME}/.local/share/forgejo-cli" ] && [ "$(readlink "${HOME}/.local/share/forgejo-cli")" = "/dc/fj/data" ]'
check "~/.config/forgejo-cli is a symlink to the volume" bash -c '[ -L "${HOME}/.config/forgejo-cli" ] && [ "$(readlink "${HOME}/.config/forgejo-cli")" = "/dc/fj/config" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.local/share/forgejo-cli/.persistence-check" && grep -q persistence-check /dc/fj/data/.persistence-check'

reportResults
