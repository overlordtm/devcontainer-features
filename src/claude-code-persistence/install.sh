#!/usr/bin/env bash
set -euo pipefail

FEATURE_ID="claude-code-persistence"
CONFIG_DIR="/dc/claude"
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

# Create the mount point in the image. A fresh Docker named volume copies the
# ownership of this directory the first time it is mounted.
mkdir -p "${CONFIG_DIR}"
chown -R "${USER_NAME}" "${CONFIG_DIR}"

# CLAUDE_CONFIG_DIR is also set through `containerEnv`, but login shells that
# do not inherit the container environment (for example SSH sessions) need it
# exported as well.
mkdir -p /etc/profile.d
cat > /etc/profile.d/00-claude-code-persistence.sh <<'EOF'
export CLAUDE_CONFIG_DIR=/dc/claude
EOF
chmod 0644 /etc/profile.d/00-claude-code-persistence.sh

# Some tools ignore CLAUDE_CONFIG_DIR and read ~/.claude directly. Keep a
# symlink so both paths always refer to the persistent volume.
CLAUDE_LINK="${USER_HOME}/.claude"
if [ -L "${CLAUDE_LINK}" ] && [ "$(readlink "${CLAUDE_LINK}")" = "${CONFIG_DIR}" ]; then
    echo "${CLAUDE_LINK} already points to ${CONFIG_DIR}"
else
    if [ -e "${CLAUDE_LINK}" ] || [ -L "${CLAUDE_LINK}" ]; then
        BACKUP="${CLAUDE_LINK}.pre-persistence"
        if [ -e "${BACKUP}" ] || [ -L "${BACKUP}" ]; then
            BACKUP="${BACKUP}.$(date +%s)"
        fi
        echo "Moving existing ${CLAUDE_LINK} to ${BACKUP}"
        mv "${CLAUDE_LINK}" "${BACKUP}"
    fi
    ln -s "${CONFIG_DIR}" "${CLAUDE_LINK}"
    echo "Created symlink ${CLAUDE_LINK} -> ${CONFIG_DIR}"
fi

# Lifecycle script. Runs after the volume is mounted so it can repair volume
# ownership and migrate data from a pre-feature installation.
mkdir -p "${SCRIPTS_DIR}"
cp "$(dirname "$0")/oncreate.sh" "${SCRIPTS_DIR}/oncreate.sh"
chmod 0755 "${SCRIPTS_DIR}/oncreate.sh"

echo "Finished installing ${FEATURE_ID}"
