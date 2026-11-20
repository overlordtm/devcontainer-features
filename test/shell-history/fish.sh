#!/bin/bash
# shellcheck disable=SC1091,SC2016 # test lib is injected; $HOME expands in the spawned shell.
set -e

source dev-container-features-test-lib

check "fish is installed" command -v fish
check "fish config is syntactically valid" fish --no-execute "${HOME}/.config/shell-history/config.fish"
check "fish links its history into the volume" bash -c 'rm -f "$HOME/.local/share/fish/fish_history"; fish -c "source \"$HOME/.config/shell-history/config.fish\""; [ -L "$HOME/.local/share/fish/fish_history" ] && [ "$(readlink "$HOME/.local/share/fish/fish_history")" = "/dc/shell-history/fish_history" ]'
check "writes through the fish history link reach the volume" bash -c 'echo shell-history-fish-test > "$HOME/.local/share/fish/fish_history" && grep -q shell-history-fish-test /dc/shell-history/fish_history'

reportResults
