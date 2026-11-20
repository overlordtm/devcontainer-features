#!/bin/bash
set -e

source dev-container-features-test-lib

check "plugins are replaced by the set value" grep -qxF 'plugins=(zsh-autosuggestions git)' "${HOME}/.zshrc"
check "plugins not in the set value are removed" bash -c '! grep -q "docker" "$HOME/.zshrc"'
check "other .zshrc settings are preserved" grep -qxF 'ZSH_THEME="robbyrussell"' "${HOME}/.zshrc"

reportResults
