#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-2.42.0}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        2.42.0:linux-x86_64) printf '%s\n' 'aadc6bdaf7ec3af4660f0699daa23986434dd615c7fa9149ec7de237a37e8572' ;;
        2.42.0:linux-aarch64) printf '%s\n' 'ec914b286c4cad7e6e7d81b5b4190ef435482a7cccc5013747b1285a993f3c37' ;;
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
        echo "Unsupported package manager. Please install curl, ca-certificates, and unzip manually." >&2
        exit 1
    fi
}

MISSING_PACKAGES=""
if ! command -v curl >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} curl"
fi
if ! command -v unzip >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} unzip"
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
    # The AWS CLI release tags are not exposed through the GitHub "latest
    # release" redirect, so read the version from the v2 branch instead.
    if version="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://raw.githubusercontent.com/aws/aws-cli/v2/awscli/__init__.py" 2>/dev/null \
        | sed -n "s/^__version__[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p")"; then
        case "${version}" in
            '' | *[!0-9.]*) ;;
            *.*.*) printf '%s\n' "${version}"; return 0 ;;
        esac
    fi

    return 1
}

if [ "${VERSION}" = "latest" ]; then
    echo "Looking up the latest AWS CLI release..."
    if ! VERSION="$(resolve_latest_version)"; then
        echo "Could not determine the latest AWS CLI version." >&2
        echo "Set the 'version' option to a specific release (for example \"2.42.0\") to skip the lookup." >&2
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
        echo "Unsupported architecture: $(uname -m). The AWS CLI v2 publishes Linux bundles for x86_64 and aarch64." >&2
        exit 1
        ;;
esac

BUNDLE_NAME="awscli-exe-linux-${ARCH}-${VERSION}.zip"
DOWNLOAD_URL="https://awscli.amazonaws.com/${BUNDLE_NAME}"

echo "Installing the AWS CLI ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${BUNDLE_NAME}" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/${BUNDLE_NAME}" "AWS CLI" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

unzip -q "${TMP_DIR}/${BUNDLE_NAME}" -d "${TMP_DIR}"

if [ ! -x "${TMP_DIR}/aws/install" ]; then
    echo "Unexpected AWS CLI archive layout." >&2
    exit 1
fi

"${TMP_DIR}/aws/install" --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin --update

/usr/local/bin/aws --version
