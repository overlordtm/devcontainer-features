#!/bin/bash
set -e

source dev-container-features-test-lib

check "requested plugins are removed" grep -qxF 'plugins=(git)' "${HOME}/.zshrc"
check "removing a missing plugin is not an error" bash -c '! grep -q "missing-plugin" "$HOME/.zshrc"'
check "other .zshrc settings are preserved" grep -qxF 'ZSH_THEME="robbyrussell"' "${HOME}/.zshrc"

reportResults
