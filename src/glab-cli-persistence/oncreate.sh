#!/bin/sh
set -eu

FEATURE_ID="glab-cli-persistence"
VOLUME_DIR="/dc/glab"

log() {
    echo "[${FEATURE_ID}] $*"
}

if [ ! -d "${VOLUME_DIR}" ]; then
    log "warning: ${VOLUME_DIR} is not mounted; skipping persistence setup"
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
if [ ! -w "${VOLUME_DIR}" ] || [ ! -w "${VOLUME_DIR}/config" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        if ! sudo -n chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}"; then
            log "warning: could not change ownership of ${VOLUME_DIR}"
        fi
    else
        log "warning: ${VOLUME_DIR} is not writable and sudo is unavailable; glab may fail to save logins"
    fi
fi

# If the feature moved an existing ~/.config/glab-cli aside at build time, seed
# the empty volume with that data on the first container creation.
BACKUP="${HOME_DIR}/.config/glab-cli.pre-persistence"
if [ -d "${BACKUP}" ] && [ -z "$(ls -A "${VOLUME_DIR}/config" 2>/dev/null)" ]; then
    log "Migrating ${BACKUP} into ${VOLUME_DIR}/config"
    if ! cp -a "${BACKUP}/." "${VOLUME_DIR}/config/"; then
        log "warning: could not migrate data from ${BACKUP}"
    fi
fi

log "ready (persistent config: ${VOLUME_DIR}/config)"
