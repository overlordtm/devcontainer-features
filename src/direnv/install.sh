#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"
CONFIGURE_SHELLS="${CONFIGURESHELLS:-true}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

install_packages() {
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        if [ "$(find /var/lib/apt/lists -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" = "0" ]; then
            apt-get update -y
        fi
        apt-get install -y --no-install-recommends "$@"
    elif command -v apk >/dev/null 2>&1; then
        apk add --no-cache "$@"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y "$@"
    elif command -v microdnf >/dev/null 2>&1; then
        microdnf install -y "$@"
    elif command -v yum >/dev/null 2>&1; then
        yum install -y "$@"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "$@"
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive install "$@"
    else
        echo "Unsupported package manager. Please install curl and ca-certificates manually." >&2
        exit 1
    fi
}

MISSING_PACKAGES=""
if ! command -v curl >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} curl"
fi
if [ ! -f /etc/ssl/certs/ca-certificates.crt ] \
    && [ ! -f /etc/pki/tls/certs/ca-bundle.crt ] \
    && [ ! -f /etc/ssl/cert.pem ]; then
    MISSING_PACKAGES="${MISSING_PACKAGES} ca-certificates"
fi
if [ -n "${MISSING_PACKAGES}" ]; then
    # shellcheck disable=SC2086
    install_packages ${MISSING_PACKAGES}
fi

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="amd64"
        ;;
    aarch64 | arm64)
        ARCH="arm64"
        ;;
    armv7l | armv6l | arm)
        ARCH="arm"
        ;;
    i386 | i686 | 386)
        ARCH="386"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

VERSION="${VERSION#v}"
if [ "${VERSION}" = "latest" ]; then
    DOWNLOAD_URL="https://github.com/direnv/direnv/releases/latest/download/direnv.linux-${ARCH}"
else
    DOWNLOAD_URL="https://github.com/direnv/direnv/releases/download/v${VERSION}/direnv.linux-${ARCH}"
fi

echo "Installing direnv ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/direnv" "${DOWNLOAD_URL}"
chmod 0755 "${TMP_DIR}/direnv"
mkdir -p /usr/local/bin
mv "${TMP_DIR}/direnv" /usr/local/bin/direnv

/usr/local/bin/direnv version

if [ "${CONFIGURE_SHELLS}" != "true" ]; then
    echo "Skipping shell configuration (configureShells=false)"
    exit 0
fi

add_hook() {
    local file="$1"
    local shell="$2"

    mkdir -p "$(dirname "${file}")"
    touch "${file}"

    if grep -q "direnv hook ${shell}" "${file}"; then
        echo "direnv ${shell} hook already present in ${file}"
        return
    fi

    {
        echo ""
        echo "# direnv (added by devcontainer feature)"
        echo "eval \"\$(direnv hook ${shell})\""
    } >> "${file}"
    echo "Added direnv ${shell} hook to ${file}"
}

# Login shells: works for both bash and zsh and is safe on minimal images.
mkdir -p /etc/profile.d
cat > /etc/profile.d/direnv.sh <<'EOF'
if command -v direnv >/dev/null 2>&1; then
    if [ -n "${BASH_VERSION-}" ]; then
        eval "$(direnv hook bash)"
    elif [ -n "${ZSH_VERSION-}" ]; then
        eval "$(direnv hook zsh)"
    fi
fi
EOF
chmod 0644 /etc/profile.d/direnv.sh

# Interactive bash shells read one of these files depending on the distro.
if [ -f /etc/bash.bashrc ]; then
    add_hook /etc/bash.bashrc bash
fi
if [ -f /etc/bashrc ]; then
    add_hook /etc/bashrc bash
fi

# Interactive zsh sessions read /etc/zsh/zshrc on Debian/Ubuntu and /etc/zshrc
# on Fedora/RHEL/openSUSE.
if command -v zsh >/dev/null 2>&1; then
    add_hook /etc/zsh/zshrc zsh
    add_hook /etc/zshrc zsh
fi

# Fish reads system-wide configuration from /etc/fish/conf.d.
mkdir -p /etc/fish/conf.d
cat > /etc/fish/conf.d/direnv.fish <<'EOF'
if type -q direnv
    direnv hook fish | source
end
EOF
chmod 0644 /etc/fish/conf.d/direnv.fish

echo "direnv installed and shell hooks configured"
