#!/bin/sh
set -eu

FEATURE_ID="claude-code-persistence"
CONFIG_DIR="/dc/claude"

log() {
    echo "[${FEATURE_ID}] $*"
}

if [ ! -d "${CONFIG_DIR}" ]; then
    log "warning: ${CONFIG_DIR} is not mounted; skipping persistence setup"
    exit 0
fi

HOME_DIR="${HOME:-}"
if [ -z "${HOME_DIR}" ]; then
    HOME_DIR="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6 || true)"
fi
if [ -z "${HOME_DIR}" ]; then
    HOME_DIR="/root"
fi

# Fresh volumes normally inherit the ownership of the image directory, but
# volumes created by an older container (or a different image user) may not.
if [ ! -w "${CONFIG_DIR}" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$(id -u):$(id -g)" "${CONFIG_DIR}"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        if ! sudo -n chown -R "$(id -u):$(id -g)" "${CONFIG_DIR}"; then
            log "warning: could not change ownership of ${CONFIG_DIR}"
        fi
    else
        log "warning: ${CONFIG_DIR} is not writable and sudo is unavailable; Claude Code may fail to save state"
    fi
fi

# If the feature moved an existing ~/.claude aside at build time, seed the
# empty volume with that data on the first container creation.
BACKUP="${HOME_DIR}/.claude.pre-persistence"
if [ -d "${BACKUP}" ] && [ -z "$(ls -A "${CONFIG_DIR}" 2>/dev/null)" ]; then
    log "Migrating ${BACKUP} into ${CONFIG_DIR}"
    if ! cp -a "${BACKUP}/." "${CONFIG_DIR}/"; then
        log "warning: could not migrate data from ${BACKUP}"
    fi
fi

# With CLAUDE_CONFIG_DIR set, Claude Code keeps ~/.claude.json inside the
# config directory. Import the legacy file if this is its first run.
if [ ! -e "${CONFIG_DIR}/.claude.json" ] && [ -f "${HOME_DIR}/.claude.json" ]; then
    log "Migrating ${HOME_DIR}/.claude.json into ${CONFIG_DIR}/.claude.json"
    if ! cp -a "${HOME_DIR}/.claude.json" "${CONFIG_DIR}/.claude.json"; then
        log "warning: could not migrate ${HOME_DIR}/.claude.json"
    fi
fi

log "ready (persistent config: ${CONFIG_DIR})"
