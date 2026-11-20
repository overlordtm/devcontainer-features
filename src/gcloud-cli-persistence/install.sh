#!/usr/bin/env bash
set -euo pipefail

FEATURE_ID="gcloud-cli-persistence"
VOLUME_DIR="/dc/gcloud"
SCRIPTS_DIR="/usr/local/share/${FEATURE_ID}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

USER_NAME="${_REMOTE_USER:-root}"
USER_HOME="${_REMOTE_USER_HOME:-}"
if [ -z "${USER_HOME}" ]; then
    USER_HOME="$(getent passwd "${USER_NAME}" 2>/dev/null | cut -d: -f6 || true)"
fi
if [ -z "${USER_HOME}" ]; then
    USER_HOME="/root"
fi

echo "Setting up ${FEATURE_ID} for ${USER_NAME} (${USER_HOME})..."

# Docker copies the ownership of the mount point into a fresh named volume the
# first time it is used, so create the directory as the remote user.
mkdir -p "${VOLUME_DIR}/config"
chown -R "${USER_NAME}" "${VOLUME_DIR}"

ensure_parent_dir() {
    local dir="$1"
    mkdir -p "${dir}"

    # Some tools create their XDG directory as root. Fix up any root-owned
    # components we just created, without touching directories owned by the
    # remote user.
    local current="${dir}"
    while [ "${current}" != "${USER_HOME}" ] && [ "${current}" != "/" ] && [ "${current}" != "." ]; do
        if [ "$(stat -c '%u' "${current}" 2>/dev/null || echo 0)" = "0" ]; then
            chown "${USER_NAME}" "${current}"
        fi
        current="$(dirname "${current}")"
    done
}

link_dir() {
    local source_dir="$1"
    local link_path="$2"

    ensure_parent_dir "$(dirname "${link_path}")"

    if [ -L "${link_path}" ] && [ "$(readlink "${link_path}")" = "${source_dir}" ]; then
        echo "${link_path} already points to ${source_dir}"
        return
    fi

    if [ -e "${link_path}" ] || [ -L "${link_path}" ]; then
        local backup="${link_path}.pre-persistence"
        if [ -e "${backup}" ] || [ -L "${backup}" ]; then
            backup="${backup}.$(date +%s)"
        fi
        echo "Moving existing ${link_path} to ${backup}"
        mv "${link_path}" "${backup}"
    fi

    ln -s "${source_dir}" "${link_path}"
    echo "Created symlink ${link_path} -> ${source_dir}"
}

# gcloud keeps its configurations, credentials, access tokens, and logs in
# ~/.config/gcloud by default.
link_dir "${VOLUME_DIR}/config" "${USER_HOME}/.config/gcloud"

# Lifecycle script. Runs after the volume is mounted so it can repair volume
# ownership and migrate data from a pre-feature installation.
mkdir -p "${SCRIPTS_DIR}"
cp "$(dirname "$0")/oncreate.sh" "${SCRIPTS_DIR}/oncreate.sh"
chmod 0755 "${SCRIPTS_DIR}/oncreate.sh"

echo "Finished installing ${FEATURE_ID}"
