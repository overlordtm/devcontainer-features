#!/bin/bash
set -e

source dev-container-features-test-lib

check "added plugins are present" grep -qxF 'plugins=(git docker zsh-autosuggestions)' "${HOME}/.zshrc"
check "duplicate plugin is not added twice" bash -c '[ "$(grep -o "docker" "$HOME/.zshrc" | wc -l)" -eq 1 ]'
check "other .zshrc settings are preserved" grep -qxF 'ZSH_THEME="robbyrussell"' "${HOME}/.zshrc"
check "only one plugins line exists" bash -c '[ "$(grep -cE "^[[:space:]]*plugins[[:space:]]*=" "$HOME/.zshrc")" -eq 1 ]'

reportResults
