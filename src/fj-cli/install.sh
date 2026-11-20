#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-latest}"

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

install_with_cargo() {
    echo "Falling back to 'cargo install forgejo-cli'..."
    if ! command -v cargo >/dev/null 2>&1; then
        echo "The fj release binary requires glibc/OpenSSL 3, which this image does not provide," >&2
        echo "and cargo is not installed. Use a glibc-based image (Debian 12+, Ubuntu 22.04+) or" >&2
        echo "install Rust and rerun the feature." >&2
        exit 1
    fi
    cargo install forgejo-cli --locked --root /usr/local
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

if is_musl; then
    install_with_cargo
    /usr/local/bin/fj version
    exit 0
fi

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest fj release..."
    VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://codeberg.org/api/v1/repos/forgejo-contrib/forgejo-cli/releases/latest" \
        | grep -o '"tag_name":"[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 \
        | sed 's/^v//')"

    if [ -z "${VERSION}" ]; then
        echo "Could not determine the latest fj version." >&2
        exit 1
    fi
fi
VERSION="${VERSION#v}"

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="x86_64"
        ;;
    aarch64 | arm64)
        ARCH="aarch64"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m). fj publishes prebuilt binaries for x86_64 and aarch64 Linux only." >&2
        exit 1
        ;;
esac

DOWNLOAD_URL="https://codeberg.org/forgejo-contrib/forgejo-cli/releases/download/v${VERSION}/forgejo-cli-${ARCH}-linux.tar.gz"

echo "Installing fj ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/fj.tar.gz" "${DOWNLOAD_URL}"
tar -xzf "${TMP_DIR}/fj.tar.gz" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/fj" ]; then
    echo "Unexpected fj archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "${TMP_DIR}/fj" /usr/local/bin/fj 2>/dev/null \
    || {
        cp "${TMP_DIR}/fj" /usr/local/bin/fj
        chmod 0755 /usr/local/bin/fj
    }

if ! /usr/local/bin/fj version; then
    echo "The downloaded fj binary could not run on this image."
    install_with_cargo
fi

/usr/local/bin/fj version
