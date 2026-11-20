#!/bin/sh
set -eu

FEATURE_ID="shell-history"
VOLUME_DIR="/dc/shell-history"

log() {
    echo "[${FEATURE_ID}] $*"
}

if [ ! -d "${VOLUME_DIR}" ]; then
    log "warning: ${VOLUME_DIR} is not mounted; skipping shell history setup"
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
if [ ! -w "${VOLUME_DIR}" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}" \
            || log "warning: could not change ownership of ${VOLUME_DIR}"
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo -n chown -R "$(id -u):$(id -g)" "${VOLUME_DIR}" \
            || log "warning: could not change ownership of ${VOLUME_DIR}"
    else
        log "warning: ${VOLUME_DIR} is not writable and sudo is unavailable; shell history may not be saved"
    fi
fi

import_history() {
    source_file="$1"
    target_file="$2"

    if [ -f "${source_file}" ] && [ ! -e "${target_file}" ]; then
        log "Importing ${source_file} into ${target_file}"
        if ! cp -p "${source_file}" "${target_file}"; then
            log "warning: could not import ${source_file}"
        fi
    fi
}

# Seed the volume with history that predates the Feature.
import_history "${HOME_DIR}/.bash_history" "${VOLUME_DIR}/.bash_history"
import_history "${HOME_DIR}/.zsh_history" "${VOLUME_DIR}/.zsh_history"

# Fish has no way to point at a history file outside its data directory, so
# link the history file instead. A pre-existing file is merged into the volume
# on the first container creation.
FISH_DATA_DIR="${XDG_DATA_HOME:-${HOME_DIR}/.local/share}/fish"
FISH_HISTORY="${FISH_DATA_DIR}/fish_history"
if mkdir -p "${FISH_DATA_DIR}"; then
    link_fish_history=1
    if [ -f "${FISH_HISTORY}" ] && [ ! -L "${FISH_HISTORY}" ]; then
        if [ ! -e "${VOLUME_DIR}/fish_history" ]; then
            log "Importing ${FISH_HISTORY} into ${VOLUME_DIR}/fish_history"
            if ! cp -p "${FISH_HISTORY}" "${VOLUME_DIR}/fish_history"; then
                log "warning: could not import ${FISH_HISTORY}"
                link_fish_history=0
            fi
        else
            # Fish history records start with "- cmd:", so concatenation is
            # safe when fish replaced the symlink with a regular file.
            if ! cat "${FISH_HISTORY}" >> "${VOLUME_DIR}/fish_history"; then
                log "warning: could not merge ${FISH_HISTORY}"
                link_fish_history=0
            fi
        fi
        if [ "${link_fish_history}" -eq 1 ]; then
            rm -f "${FISH_HISTORY}"
        else
            log "warning: leaving ${FISH_HISTORY} in place"
        fi
    fi
    if [ "${link_fish_history}" -eq 1 ]; then
        if ! ln -sfn "${VOLUME_DIR}/fish_history" "${FISH_HISTORY}"; then
            log "warning: could not link ${FISH_HISTORY} to the volume"
        fi
    fi
else
    log "warning: could not create ${FISH_DATA_DIR}"
fi

log "ready (persistent history: ${VOLUME_DIR})"
