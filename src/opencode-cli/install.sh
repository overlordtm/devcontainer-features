#!/bin/sh
set -eu

VERSION="${VERSION:-latest}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<target>"
# and <target> matches the npm platform package name suffix.
lookup_checksum() {
    case "$1:$2" in
        2.3.2:linux-x64) printf '%s\n' '845468e35aa5a2b574945a0b96675e64c604f5279ced9aa7245068d8c0b6f6bb' ;;
        2.3.2:linux-arm64) printf '%s\n' '91a937129efdae8eb8c0c5018ae533f9f35117f26ffd9a4d1f7a5f9da1e69306' ;;
        2.3.2:linux-x64-baseline) printf '%s\n' 'e567dcdb1310dcae4e442077e0d508e10a80c1b996131a04dc9b978cdd26e5cd' ;;
        2.3.2:linux-x64-musl) printf '%s\n' 'b6a1d2a6271f0d2703d60e6345113cb04d216a0a7c09756ac63f3ad038ea1117' ;;
        2.3.2:linux-arm64-musl) printf '%s\n' 'a22614aea091eb25484df9169bfa7335bd6b0351bdd47503d8e26dc8441256ee' ;;
        2.3.2:linux-x64-baseline-musl) printf '%s\n' '6b6e9f6bf26cb93f68eece94dcf80b5e2fa40ab3f17a6bb0a57c749a8a31dd0c' ;;
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

is_musl() {
    [ -f /etc/alpine-release ] && return 0
    if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
        return 0
    fi
    return 1
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
# The musl build is dynamically linked against libstdc++, which Alpine does
# not include by default.
if is_musl && command -v apk >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} libstdc++"
fi
if [ -n "${MISSING_PACKAGES}" ]; then
    # shellcheck disable=SC2086
    install_packages ${MISSING_PACKAGES}
fi

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="x64"
        ;;
    aarch64 | arm64)
        ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m). OpenCode publishes Linux x64 and arm64 builds." >&2
        exit 1
        ;;
esac

TARGET="linux-${ARCH}"

# OpenCode publishes a baseline build for x64 CPUs without AVX2.
if [ "${ARCH}" = "x64" ] && ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
    TARGET="${TARGET}-baseline"
fi

if is_musl; then
    TARGET="${TARGET}-musl"
fi

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest OpenCode release..."
    VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://opencode.ai/update/api/latest/cli/npm" \
        | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' \
        | head -n 1)"

    if [ -z "${VERSION}" ]; then
        VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
            "https://registry.npmjs.org/@opencode%2fcli/latest" \
            | grep -o '"version":"[^"]*"' \
            | head -n 1 \
            | cut -d'"' -f4)"
    fi

    if [ -z "${VERSION}" ]; then
        echo "Could not determine the latest OpenCode version." >&2
        exit 1
    fi
fi
VERSION="${VERSION#v}"

PACKAGE_NAME="@opencode/cli-${TARGET}"
TARBALL_NAME="cli-${TARGET}-${VERSION}.tgz"
DOWNLOAD_URL="https://registry.npmjs.org/${PACKAGE_NAME}/-/${TARBALL_NAME}"

echo "Installing OpenCode ${VERSION} for ${TARGET}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if ! curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${TARBALL_NAME}" "${DOWNLOAD_URL}"; then
    echo "Could not download OpenCode ${VERSION} for ${TARGET}." >&2
    echo "Check that the version exists: https://www.npmjs.com/package/${PACKAGE_NAME}?activeTab=versions" >&2
    exit 1
fi

if ! verify_download "${TMP_DIR}/${TARBALL_NAME}" "OpenCode" "${VERSION}" "${TARGET}"; then
    exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL_NAME}" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/package/bin/opencode" ]; then
    echo "Unexpected OpenCode archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "${TMP_DIR}/package/bin/opencode" /usr/local/bin/opencode 2>/dev/null \
    || {
        cp "${TMP_DIR}/package/bin/opencode" /usr/local/bin/opencode
        chmod 0755 /usr/local/bin/opencode
    }

# OpenCode 2 also publishes an `opencode2` alias for older tooling.
ln -sfn opencode /usr/local/bin/opencode2

/usr/local/bin/opencode --version
echo "OpenCode CLI installed successfully"
