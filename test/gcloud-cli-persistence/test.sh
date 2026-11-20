#!/bin/bash
set -e

source dev-container-features-test-lib

check "persistent volume directory exists" test -d /dc/gcloud
check "config directory exists" test -d /dc/gcloud/config
check "persistent volume is writable" test -w /dc/gcloud
check "onCreate script is installed and executable" test -x /usr/local/share/gcloud-cli-persistence/oncreate.sh
check "~/.config/gcloud is a symlink to the volume" bash -c '[ -L "${HOME}/.config/gcloud" ] && [ "$(readlink "${HOME}/.config/gcloud")" = "/dc/gcloud/config" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.config/gcloud/.persistence-check" && grep -q persistence-check /dc/gcloud/config/.persistence-check'

reportResults
