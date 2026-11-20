#!/bin/bash
# shellcheck disable=SC1091,SC2016 # test lib is injected; $HOME expands in the spawned shell.
set -e

source dev-container-features-test-lib

check "persistent history directory exists" test -d /dc/shell-history
check "persistent history directory is writable" test -w /dc/shell-history
check "onCreate script is installed and executable" test -x /usr/local/share/shell-history/oncreate.sh
check "bash config is generated" grep -q 'export HISTFILE="/dc/shell-history/.bash_history"' "${HOME}/.config/shell-history/bash.sh"
check "default historySize is applied" grep -q '^HISTSIZE=10000$' "${HOME}/.config/shell-history/bash.sh"
check "zsh config is generated" grep -q 'export HISTFILE="/dc/shell-history/.zsh_history"' "${HOME}/.config/shell-history/zsh.sh"
check "fish config is generated" grep -q '/dc/shell-history' "${HOME}/.config/shell-history/config.fish"
check "\$HOME/.bashrc sources the bash config" grep -q '.config/shell-history/bash.sh' "${HOME}/.bashrc"
check "\$HOME/.zshrc sources the zsh config" grep -q '.config/shell-history/zsh.sh' "${HOME}/.zshrc"
check "fish config sources the fish config" grep -q '.config/shell-history/config.fish' "${HOME}/.config/fish/config.fish"
check "fish history is linked into the volume" bash -c '[ -L "$HOME/.local/share/fish/fish_history" ] && [ "$(readlink "$HOME/.local/share/fish/fish_history")" = "/dc/shell-history/fish_history" ]'
check "bash uses the persistent HISTFILE" bash -c 'source "$HOME/.config/shell-history/bash.sh" && [ "$HISTFILE" = "/dc/shell-history/.bash_history" ]'
check "bash writes history to the volume" bash -c 'export HISTFILE="/dc/shell-history/.bash_history"; set -o history; history -s shell-history-bash-test; history -a; grep -q shell-history-bash-test /dc/shell-history/.bash_history'
check "onCreate imports existing bash history" bash -c 'echo shell-history-import-test > "$HOME/.bash_history"; rm -f /dc/shell-history/.bash_history; /usr/local/share/shell-history/oncreate.sh >/dev/null; grep -q shell-history-import-test /dc/shell-history/.bash_history'
check "onCreate migrates fish history and repairs the link" bash -c 'rm -f "$HOME/.local/share/fish/fish_history"; echo "- cmd: shell-history-fish-import-test" > "$HOME/.local/share/fish/fish_history"; /usr/local/share/shell-history/oncreate.sh >/dev/null; [ -L "$HOME/.local/share/fish/fish_history" ] && grep -q shell-history-fish-import-test /dc/shell-history/fish_history'

if command -v zsh >/dev/null 2>&1; then
    check "zsh uses the persistent HISTFILE" zsh -c 'source "$HOME/.config/shell-history/zsh.sh"; [[ "$HISTFILE" = "/dc/shell-history/.zsh_history" ]]'
    check "zsh has a positive SAVEHIST" zsh -c 'source "$HOME/.config/shell-history/zsh.sh"; (( SAVEHIST > 0 ))'
fi

if command -v fish >/dev/null 2>&1; then
    check "fish config is syntactically valid" fish --no-execute "${HOME}/.config/shell-history/config.fish"
fi

reportResults
