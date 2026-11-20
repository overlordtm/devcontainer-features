#!/bin/bash
set -e

source dev-container-features-test-lib

check "CLAUDE_CONFIG_DIR is set" test "${CLAUDE_CONFIG_DIR}" = "/dc/claude"
check "persistent config directory exists" test -d /dc/claude
check "persistent config directory is writable" test -w /dc/claude
check "onCreate script is installed and executable" test -x /usr/local/share/claude-code-persistence/oncreate.sh
check "~/.claude is a symlink to the volume" bash -c '[ -L "${HOME}/.claude" ] && [ "$(readlink "${HOME}/.claude")" = "/dc/claude" ]'
check "writes through the symlink reach the volume" bash -c 'echo persistence-check > "${HOME}/.claude/.persistence-check" && grep -q persistence-check /dc/claude/.persistence-check'
check "login shells inherit CLAUDE_CONFIG_DIR" bash -lc 'test "${CLAUDE_CONFIG_DIR}" = "/dc/claude"'

reportResults
