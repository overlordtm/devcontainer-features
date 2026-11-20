#!/bin/sh
set -eu

FEATURE_ID="gh-cli-persistence"
VOLUME_DIR="/dc/gh"

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
if [ ! -w "${VOLUME_DIR}" ] || [ ! -w "${VOLUME_DIR}/config" ] || [ ! -w "${VOLUME_DIR}/data" ] || [ ! -w "${VOLUME_DIR}/state" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        if ! sudo -n chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}"; then
            log "warning: could not change ownership of ${VOLUME_DIR}"
        fi
    else
        log "warning: ${VOLUME_DIR} is not writable and sudo is unavailable; gh may fail to save logins"
    fi
fi

# If the feature moved existing XDG directories aside at build time, seed the
# empty volume with that data on the first container creation.
migrate() {
    source_dir="$1"
    target_dir="$2"

    if [ -d "${source_dir}" ] && [ -z "$(ls -A "${target_dir}" 2>/dev/null)" ]; then
        log "Migrating ${source_dir} into ${target_dir}"
        if ! cp -a "${source_dir}/." "${target_dir}/"; then
            log "warning: could not migrate data from ${source_dir}"
        fi
    fi
}

migrate "${HOME_DIR}/.config/gh.pre-persistence" "${VOLUME_DIR}/config"
migrate "${HOME_DIR}/.local/share/gh.pre-persistence" "${VOLUME_DIR}/data"
migrate "${HOME_DIR}/.local/state/gh.pre-persistence" "${VOLUME_DIR}/state"

log "ready (persistent data: ${VOLUME_DIR})"
