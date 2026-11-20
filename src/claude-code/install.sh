#!/bin/sh
set -eu

VERSION_INPUT="${VERSION:-2.1.329}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        2.1.329:linux-x64) printf '%s\n' '30e2724e2aecb1bf5dc9f3130901afb71c5fa229051c190a6d7ad9aff6378d6d' ;;
        2.1.329:linux-arm64) printf '%s\n' '8489e2c7ba7846b4681b84e559fed4ed5bb265e129e21dc9de9e322157fb2bea' ;;
        2.1.329:linux-x64-musl) printf '%s\n' '1ad6247ddadb174a78ce065483d860e4287f60710eabeb60ccde8b125dc8ee2f' ;;
        2.1.329:linux-arm64-musl) printf '%s\n' '9fbb58c26c2589620d365e6c6d495137854e4dcff30d9f6c732cd355cae4618c' ;;
        2.1.311:linux-x64) printf '%s\n' '86dc1fcc69498159eaf15f446613e847010f9036bfbbdffd4c49350be8489ada' ;;
        2.1.311:linux-arm64) printf '%s\n' '2e2496c9a8065df93acb0fca2d341f59a6b8777649b2e025ab8c9bcd5eef61f3' ;;
        2.1.311:linux-x64-musl) printf '%s\n' 'cd40dd327145ee47aa0deacd571801c1d782388f709d71242eee6b91de8ed11f' ;;
        2.1.311:linux-arm64-musl) printf '%s\n' '172150e3f9ea07e8e2e2e29862d7d9a25f5c234d8e909e4063df237665bf09b9' ;;
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
        echo "Unsupported package manager. Please install curl, ca-certificates, zstd, awk, and sed manually." >&2
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
if ! command -v zstd >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} zstd"
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
        echo "Unsupported architecture: $(uname -m). Claude Code publishes Linux x64 and arm64 builds." >&2
        exit 1
        ;;
esac

PLATFORM="linux-${ARCH}"

is_musl() {
    [ -f /etc/alpine-release ] && return 0
    [ -f /lib/libc.musl-x86_64.so.1 ] && return 0
    [ -f /lib/libc.musl-aarch64.so.1 ] && return 0
    if command -v ldd >/dev/null 2>&1 && ldd /bin/ls 2>&1 | grep -qi musl; then
        return 0
    fi
    return 1
}

if is_musl; then
    PLATFORM="${PLATFORM}-musl"
fi

case "${VERSION_INPUT}" in
    latest | stable)
        echo "Looking up the ${VERSION_INPUT} Claude Code release..."
        if ! VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
            "https://downloads.claude.ai/claude-code-releases/${VERSION_INPUT}")"; then
            echo "Could not determine the ${VERSION_INPUT} Claude Code release." >&2
            echo "Set the 'version' option to a specific release (for example \"2.1.329\") to skip the lookup." >&2
            exit 1
        fi
        ;;
    *)
        VERSION="${VERSION_INPUT#v}"
        ;;
esac

VERSION="${VERSION#v}"
if ! printf '%s' "${VERSION}" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[^[:space:]]+)?$'; then
    echo "Invalid Claude Code version: '${VERSION}'" >&2
    exit 1
fi

echo "Installing Claude Code ${VERSION} for ${PLATFORM}..."

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BINARY_URL="https://downloads.claude.ai/claude-code-releases/${VERSION}/${PLATFORM}/claude"

DOWNLOADED="false"
if command -v zstd >/dev/null 2>&1; then
    if curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/claude.zst" "${BINARY_URL}.zst" \
        && zstd -d -q -c "${TMP_DIR}/claude.zst" > "${TMP_DIR}/claude"; then
        DOWNLOADED="true"
    fi
fi

if [ "${DOWNLOADED}" != "true" ]; then
    echo "Downloading the uncompressed Claude Code binary..."
    if ! curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/claude" "${BINARY_URL}"; then
        echo "Could not download Claude Code ${VERSION} for ${PLATFORM}." >&2
        exit 1
    fi
fi

if ! verify_download "${TMP_DIR}/claude" "Claude Code" "${VERSION}" "${PLATFORM}"; then
    exit 1
fi

chmod 0755 "${TMP_DIR}/claude"
mkdir -p /usr/local/bin
rm -f /usr/local/bin/claude
install -m 0755 "${TMP_DIR}/claude" /usr/local/bin/claude 2>/dev/null \
    || {
        cp "${TMP_DIR}/claude" /usr/local/bin/claude
        chmod 0755 /usr/local/bin/claude
    }

/usr/local/bin/claude --version
echo "Claude Code installed successfully (auto-updates disabled)"
