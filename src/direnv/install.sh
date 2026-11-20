#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-2.38.2}"
CONFIGURE_SHELLS="${CONFIGURESHELLS:-true}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        2.38.2:linux-amd64) printf '%s\n' '148820a187930d36ca6a204504e5cdb30d8396cd1a97e64c3b3f10d793c11247' ;;
        2.38.2:linux-arm64) printf '%s\n' 'ec2a32dbe2f19dd085bd9315a1b4ea88b55ec288aa7eabe8723490baf466cb23' ;;
        2.38.2:linux-arm) printf '%s\n' '0a69c8acab3e8d37269381193a1fda46a5933a9dcc3ec1e5ffe719e4d364553f' ;;
        2.38.2:linux-386) printf '%s\n' '04c2adf9fa8368034c43178351fe3ba6be95ade0c968aa81b1bf187da8f8b16d' ;;
        *) return 1 ;;
    esac
}

hash_file() {
    algorithm="$1"
    file="$2"
    if command -v "${algorithm}sum" >/dev/null 2>&1; then
        "${algorithm}sum" "${file}" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a "${algorithm#sha}" "${file}" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst "-${algorithm}" "${file}" | awk '{print $NF}'
    else
        echo "No ${algorithm} implementation found (need ${algorithm}sum, shasum, or openssl)." >&2
        return 1
    fi
}

verify_hash() {
    file="$1"
    expected="$2"
    tool="$3"
    version="$4"
    platform="$5"

    case "${expected}" in
        sha256:*) expected="${expected#sha256:}" ;;
        sha512:*) expected="${expected#sha512:}" ;;
    esac
    expected="$(printf '%s' "${expected}" | tr '[:upper:]' '[:lower:]')"

    case "${expected}" in
        '' | *[!0-9a-f]*)
            echo "Invalid hash for ${tool} ${version} (${platform}). Provide a hex SHA-256 or SHA-512 digest." >&2
            return 1
            ;;
    esac

    case "${#expected}" in
        64) algorithm="sha256" ;;
        128) algorithm="sha512" ;;
        *)
            echo "Unsupported hash length for ${tool} ${version} (${platform}): expected 64 (SHA-256) or 128 (SHA-512) hex characters." >&2
            return 1
            ;;
    esac

    actual="$(hash_file "${algorithm}" "${file}")" || return 1
    actual="$(printf '%s' "${actual}" | tr '[:upper:]' '[:lower:]')"

    if [ "${actual}" != "${expected}" ]; then
        echo "Checksum verification failed for ${tool} ${version} (${platform})." >&2
        echo "  expected: ${expected}" >&2
        echo "  actual:   ${actual}" >&2
        return 1
    fi

    echo "Verified ${algorithm} checksum for ${tool} ${version} (${platform})."
}

verify_download() {
    file="$1"
    tool="$2"
    version="$3"
    platform="$4"
    hash_input="$(printf '%s' "${HASH_INPUT}" | tr '[:upper:]' '[:lower:]')"

    case "${hash_input}" in
        disabled)
            echo "WARNING: Hash verification is disabled for ${tool} ${version} (${platform})." >&2
            return 0
            ;;
        auto | '')
            if ! expected="$(lookup_checksum "${version}" "${platform}")"; then
                echo "No known checksum for ${tool} ${version} (${platform})." >&2
                echo "Set the 'hash' feature option to a SHA-256/SHA-512 digest, or to 'disabled' to skip verification." >&2
                return 1
            fi
            ;;
        *)
            expected="${hash_input}"
            ;;
    esac

    verify_hash "${file}" "${expected}" "${tool}" "${version}" "${platform}"
}

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
resolve_latest_version() {
    repo="$1"

    # Prefer the release page redirect. Unlike the REST API it is not subject
    # to the anonymous rate limit (60 requests/hour per IP), which shared CI
    # runners can easily exhaust and then receive HTTP 403 from.
    if effective_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
        --retry 3 --retry-delay 2 \
        "https://github.com/${repo}/releases/latest" 2>/dev/null)"; then
        tag="${effective_url##*/}"
        case "${tag}" in
            '' | latest | */* | *[!A-Za-z0-9._-]*) ;;
            *) printf '%s\n' "${tag#v}"; return 0 ;;
        esac
    fi

    # Fall back to the REST API in case the redirect could not be resolved.
    if tag="$(curl -fsSL --retry 3 --retry-delay 2 \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -o '"tag_name": *"[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4)"; then
        tag="${tag#v}"
        case "${tag}" in
            '' | *[!A-Za-z0-9._-]*) ;;
            *) printf '%s\n' "${tag}"; return 0 ;;
        esac
    fi

    return 1
}

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest direnv release..."
    if ! VERSION="$(resolve_latest_version "direnv/direnv")"; then
        echo "Could not determine the latest direnv version." >&2
        echo "Set the 'version' option to a specific release (for example \"2.38.2\") to skip the lookup." >&2
        exit 1
    fi
fi

DOWNLOAD_URL="https://github.com/direnv/direnv/releases/download/v${VERSION}/direnv.linux-${ARCH}"

echo "Installing direnv ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/direnv" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/direnv" "direnv" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

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
