#!/bin/sh
set -eu

FEATURE_ID="fj-cli"
STATE_FILE="/usr/local/share/fj-cli/client_id"
TARGET_DIR="/etc/fj"
TARGET_FILE="${TARGET_DIR}/client_ids"

log() {
    echo "[${FEATURE_ID}] $*"
}

[ -f "${STATE_FILE}" ] || exit 0

CLIENT_ID="$(cat "${STATE_FILE}")"
[ -n "${CLIENT_ID}" ] || exit 0

# Inline mappings are written during the image build.
if printf '%s' "${CLIENT_ID}" | grep -Eq '^[^[:space:]]+[[:space:]]+[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$'; then
    exit 0
fi

# Nothing to do if the file was already deployed at build time.
[ -e "${TARGET_FILE}" ] && exit 0

case "${CLIENT_ID}" in
    '' | . | ..)
        log "warning: invalid client_id option '${CLIENT_ID}'; skipping"
        exit 0
        ;;
esac

if ! printf '%s' "${CLIENT_ID}" | grep -Eq '^[A-Za-z0-9._-]+$'; then
    log "warning: invalid client_id filename '${CLIENT_ID}'; skipping"
    exit 0
fi

find_source() {
    name="$1"

    check_dir() {
        [ -n "$1" ] || return 1
        candidate="${1%/}/.devcontainer/${name}"
        if [ -f "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
        return 1
    }

    for base in "${containerWorkspaceFolder:-}" "${PWD:-}"; do
        if check_dir "${base}"; then
            return 0
        fi
    done

    dir="${PWD:-}"
    while [ -n "${dir}" ] && [ "${dir}" != "/" ]; do
        if check_dir "$(dirname "${dir}")"; then
            return 0
        fi
        dir="$(dirname "${dir}")"
    done

    for base in /workspaces/* /workspace /src; do
        if check_dir "${base}"; then
            return 0
        fi
    done

    return 1
}

if ! source_file="$(find_source "${CLIENT_ID}")"; then
    log "warning: client_id file '${CLIENT_ID}' was not found in .devcontainer; ${TARGET_FILE} was not created"
    exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
    install -d -m 0755 "${TARGET_DIR}"
    install -m 0644 "${source_file}" "${TARGET_FILE}"
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo -n install -d -m 0755 "${TARGET_DIR}"
    sudo -n install -m 0644 "${source_file}" "${TARGET_FILE}"
else
    log "warning: root privileges are required to write ${TARGET_FILE}; copy ${source_file} there manually"
    exit 0
fi

log "Copied ${source_file} to ${TARGET_FILE}."
