#!/bin/bash
set -e

source dev-container-features-test-lib

check "multi-line plugins are normalized to one line" grep -qxF 'plugins=(git docker kubectl)' "${HOME}/.zshrc"
check "the multi-line block is removed" bash -c '[ "$(grep -cE "^[[:space:]]*plugins[[:space:]]*=" "$HOME/.zshrc")" -eq 1 ]'
check "other .zshrc settings are preserved" grep -qxF 'ZSH_THEME="robbyrussell"' "${HOME}/.zshrc"

reportResults
