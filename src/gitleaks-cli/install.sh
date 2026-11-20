#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        8.30.1:linux-x64) printf '%s\n' '551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb' ;;
        8.30.1:linux-arm64) printf '%s\n' 'e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080' ;;
        8.30.1:linux-x32) printf '%s\n' 'a87ba11adab22b4d6c6ea28b2da60f09154d5c2fdb44d4b07015d1e0433daecb' ;;
        8.30.1:linux-armv6) printf '%s\n' '5c2a4ee657a27614e10352bed2b8f1018ef9b05fc6c037cf737776bbe1255766' ;;
        8.30.1:linux-armv7) printf '%s\n' '8d39f0d94ba0d774b2282187656fb039a2d82893ec1fd6be7d7121aae759a57d' ;;
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
        echo "Unsupported package manager. Please install curl, ca-certificates, and tar manually." >&2
        exit 1
    fi
}

MISSING_PACKAGES=""
if ! command -v curl >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} curl"
fi
if ! command -v tar >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} tar"
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

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest gitleaks release..."
    VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://api.github.com/repos/gitleaks/gitleaks/releases/latest" \
        | grep -o '"tag_name": *"[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 \
        | sed 's/^v//')"

    if [ -z "${VERSION}" ]; then
        echo "Could not determine the latest gitleaks version." >&2
        exit 1
    fi
fi
VERSION="${VERSION#v}"

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="x64"
        ;;
    aarch64 | arm64)
        ARCH="arm64"
        ;;
    i386 | i686 | 386)
        ARCH="x32"
        ;;
    armv7l | armv7)
        ARCH="armv7"
        ;;
    armv6l | armv6)
        ARCH="armv6"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m). gitleaks publishes Linux builds for x64, arm64, x32, armv6, and armv7." >&2
        exit 1
        ;;
esac

TARBALL_NAME="gitleaks_${VERSION}_linux_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/${TARBALL_NAME}"

echo "Installing gitleaks ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${TARBALL_NAME}" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/${TARBALL_NAME}" "gitleaks" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL_NAME}" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/gitleaks" ]; then
    echo "Unexpected gitleaks archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "${TMP_DIR}/gitleaks" /usr/local/bin/gitleaks 2>/dev/null \
    || {
        cp "${TMP_DIR}/gitleaks" /usr/local/bin/gitleaks
        chmod 0755 /usr/local/bin/gitleaks
    }

/usr/local/bin/gitleaks version
