#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-1.27.4}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL
# (https://go.dev/dl/).
lookup_checksum() {
    case "$1:$2" in
        1.27.4:linux-386) printf '%s\n' '6ecb45737d2315acb0dbbc97ea8e13e7c19d4c796abe8d68907c40bce6f50bf7' ;;
        1.27.4:linux-amd64) printf '%s\n' '7226736c2339719cda28fbf3a54d71aa63bcefe376e98cef00034268dab24840' ;;
        1.27.4:linux-arm64) printf '%s\n' '3392582988a273a87ab5043ee1b2c9c17a2c3c00580bf9326c47a2e0aaaeac92' ;;
        1.27.4:linux-armv6l) printf '%s\n' 'e50964c41c6e187375387939e2f380de7250eba44e2259dfeb75c540d9d585c3' ;;
        1.27.4:linux-loong64) printf '%s\n' 'e484849e103aa464e4f8dd0ab7fe174a7948c50b6156aaf24d39b25841e276dd' ;;
        1.27.4:linux-mips) printf '%s\n' '31eb199b46b91ee1f416f5a2bdf52b94146c59fb9f7600551158042f3e12d61e' ;;
        1.27.4:linux-mips64) printf '%s\n' '019bbe71ab71b7ddbf352a2ae5616c644d5a583df541c16f575142558fd93e8c' ;;
        1.27.4:linux-mips64le) printf '%s\n' '99516595926eb3d17678795c0840234808491b3b21d383bd3df318b02629b1e1' ;;
        1.27.4:linux-mipsle) printf '%s\n' '4b9609edf06a9ce7a495f5ca402f86ee557e5a3de00a135ac9a5a9e458d52881' ;;
        1.27.4:linux-ppc64) printf '%s\n' 'd03699175326d176e920d5165bc4ab274ef2311f97d5180ffc9c0d82403a650c' ;;
        1.27.4:linux-ppc64le) printf '%s\n' 'f508314644fa6f466d1935f8a34f01e7980092a4730bfb9d7fa3ffde81910d20' ;;
        1.27.4:linux-riscv64) printf '%s\n' '19e9c376178180588954a896baca95f8baa03b69216f18316af4ee2c251cc623' ;;
        1.27.4:linux-s390x) printf '%s\n' '4e56b1b9f26c649c1f3dc61fd16443d0154bd0860e59a8032b4cb05ac42f283e' ;;
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
    version="$3"
    platform="$4"

    case "${expected}" in
        sha256:*) expected="${expected#sha256:}" ;;
        sha512:*) expected="${expected#sha512:}" ;;
    esac
    expected="$(printf '%s' "${expected}" | tr '[:upper:]' '[:lower:]')"

    case "${expected}" in
        '' | *[!0-9a-f]*)
            echo "Invalid hash for Go ${version} (${platform}). Provide a hex SHA-256 or SHA-512 digest." >&2
            return 1
            ;;
    esac

    case "${#expected}" in
        64) algorithm="sha256" ;;
        128) algorithm="sha512" ;;
        *)
            echo "Unsupported hash length for Go ${version} (${platform}): expected 64 (SHA-256) or 128 (SHA-512) hex characters." >&2
            return 1
            ;;
    esac

    actual="$(hash_file "${algorithm}" "${file}")" || return 1
    actual="$(printf '%s' "${actual}" | tr '[:upper:]' '[:lower:]')"

    if [ "${actual}" != "${expected}" ]; then
        echo "Checksum verification failed for Go ${version} (${platform})." >&2
        echo "  expected: ${expected}" >&2
        echo "  actual:   ${actual}" >&2
        return 1
    fi

    echo "Verified ${algorithm} checksum for Go ${version} (${platform})."
}

verify_download() {
    file="$1"
    version="$2"
    platform="$3"
    hash_input="$(printf '%s' "${HASH_INPUT}" | tr '[:upper:]' '[:lower:]')"

    case "${hash_input}" in
        disabled)
            echo "WARNING: Hash verification is disabled for Go ${version} (${platform})." >&2
            return 0
            ;;
        auto | '')
            if ! expected="$(lookup_checksum "${version}" "${platform}")"; then
                echo "No known checksum for Go ${version} (${platform})." >&2
                echo "Set the 'hash' feature option to a SHA-256/SHA-512 digest, or to 'disabled' to skip verification." >&2
                return 1
            fi
            ;;
        *)
            expected="${hash_input}"
            ;;
    esac

    verify_hash "${file}" "${expected}" "${version}" "${platform}"
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

resolve_latest_version() {
    # The VERSION endpoint returns "go1.27.4" followed by a timestamp line.
    if latest="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://go.dev/VERSION?m=text" 2>/dev/null | sed -n '1p')"; then
        latest="${latest#go}"
        if printf '%s' "${latest}" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
            printf '%s\n' "${latest}"
            return 0
        fi
    fi

    return 1
}

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest Go release..."
    if ! VERSION="$(resolve_latest_version)"; then
        echo "Could not determine the latest Go version." >&2
        echo "Set the 'version' option to a specific release (for example \"1.27.4\") to skip the lookup." >&2
        exit 1
    fi
fi
VERSION="${VERSION#go}"
VERSION="${VERSION#v}"

case "${VERSION}" in
    '' | *[!0-9.]*)
        echo "Invalid Go version: \"${VERSION}\". Use a release such as \"1.27.4\" or \"latest\"." >&2
        exit 1
        ;;
esac

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="amd64"
        ;;
    aarch64 | arm64)
        ARCH="arm64"
        ;;
    armv6l | armv6 | armv7l | armv7 | arm)
        ARCH="armv6l"
        ;;
    i386 | i486 | i586 | i686 | 386)
        ARCH="386"
        ;;
    loongarch64 | loong64)
        ARCH="loong64"
        ;;
    mips)
        ARCH="mips"
        ;;
    mipsel)
        ARCH="mipsle"
        ;;
    mips64)
        ARCH="mips64"
        ;;
    mips64el)
        ARCH="mips64le"
        ;;
    ppc64 | powerpc64)
        ARCH="ppc64"
        ;;
    ppc64le | powerpc64le)
        ARCH="ppc64le"
        ;;
    riscv64)
        ARCH="riscv64"
        ;;
    s390x)
        ARCH="s390x"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m). Go publishes Linux archives for 386, amd64, arm64, armv6l, loong64, mips, mips64, mips64le, mipsle, ppc64, ppc64le, riscv64, and s390x." >&2
        exit 1
        ;;
esac

TARBALL_NAME="go${VERSION}.linux-${ARCH}.tar.gz"
DOWNLOAD_URL="https://go.dev/dl/${TARBALL_NAME}"
GO_ROOT="/usr/local/go"

echo "Installing Go ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${TARBALL_NAME}" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/${TARBALL_NAME}" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

# The official instructions extract the archive to /usr/local after removing
# any previous installation: https://go.dev/doc/install
if [ -e "${GO_ROOT}" ] || [ -L "${GO_ROOT}" ]; then
    rm -rf "${GO_ROOT}"
fi
tar -C /usr/local -xzf "${TMP_DIR}/${TARBALL_NAME}"

if [ ! -x "${GO_ROOT}/bin/go" ] || [ ! -x "${GO_ROOT}/bin/gofmt" ]; then
    echo "Unexpected Go archive layout: ${GO_ROOT}/bin/go not found." >&2
    exit 1
fi

# /usr/local/bin is already on PATH for every supported base image, so symlinks
# make the toolchain available without modifying shell profiles.
mkdir -p /usr/local/bin
ln -sf "${GO_ROOT}/bin/go" /usr/local/bin/go
ln -sf "${GO_ROOT}/bin/gofmt" /usr/local/bin/gofmt

/usr/local/bin/go version
