#!/bin/bash
set -e

source dev-container-features-test-lib

check "added plugin is present for the remote user" grep -q 'zsh-autosuggestions' "${HOME}/.zshrc"
check "the remote user owns .zshrc" bash -c '[ "$(stat -Lc "%U" "$HOME/.zshrc")" = "$(id -un)" ]'

reportResults
