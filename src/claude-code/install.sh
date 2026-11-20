#!/bin/sh
set -eu

VERSION_INPUT="${VERSION:-latest}"

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
        VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
            "https://downloads.claude.ai/claude-code-releases/${VERSION_INPUT}")"
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

MANIFEST_URL="https://downloads.claude.ai/claude-code-releases/${VERSION}/manifest.json"
BINARY_URL="https://downloads.claude.ai/claude-code-releases/${VERSION}/${PLATFORM}/claude"

if ! curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/manifest.json" "${MANIFEST_URL}"; then
    echo "Could not download the Claude Code ${VERSION} manifest." >&2
    exit 1
fi

CHECKSUM="$(awk -v platform="${PLATFORM}" '
    index($0, "\"" platform "\"") { in_block = 1; next }
    in_block && index($0, "\"checksum\"") {
        value = $2
        gsub(/[",]/, "", value)
        print value
        exit
    }
' "${TMP_DIR}/manifest.json")"

SIZE="$(awk -v platform="${PLATFORM}" '
    index($0, "\"" platform "\"") { in_block = 1; next }
    in_block && index($0, "\"size\"") {
        value = $2
        gsub(/[",]/, "", value)
        print value
        exit
    }
' "${TMP_DIR}/manifest.json")"

if [ -z "${CHECKSUM}" ]; then
    echo "Platform ${PLATFORM} was not found in the Claude Code ${VERSION} manifest." >&2
    exit 1
fi

DOWNLOADED="false"
if command -v zstd >/dev/null 2>&1; then
    if curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/claude.zst" "${BINARY_URL}.zst"; then
        if [ -n "${SIZE}" ]; then
            zstd -d -q -c "${TMP_DIR}/claude.zst" | head -c "${SIZE}" > "${TMP_DIR}/claude"
        else
            zstd -d -q -c "${TMP_DIR}/claude.zst" > "${TMP_DIR}/claude"
        fi
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

if ! echo "${CHECKSUM}  ${TMP_DIR}/claude" | sha256sum -c - >/dev/null 2>&1; then
    echo "Checksum verification failed for Claude Code ${VERSION}." >&2
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
