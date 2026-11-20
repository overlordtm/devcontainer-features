#!/bin/bash
# shellcheck disable=SC1091
set -e

source dev-container-features-test-lib

check "bash uses the custom history size" grep -q '^HISTSIZE=25000$' "${HOME}/.config/shell-history/bash.sh"
check "zsh uses the custom history size" grep -q '^SAVEHIST=25000$' "${HOME}/.config/shell-history/zsh.sh"

reportResults
