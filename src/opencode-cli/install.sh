#!/bin/sh
set -eu

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
