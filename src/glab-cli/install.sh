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
        1.131.0:linux-amd64) printf '%s\n' '580dbca43835b47267e512476a442f6b2e8785a82b26ccacee22bd7010662b2d' ;;
        1.131.0:linux-arm64) printf '%s\n' '7c4befd271203745b674caae2a69590ea5f9c6e5dee78bd3b40ba0e2a7c74749' ;;
        1.131.0:linux-armv6) printf '%s\n' '67c7223e95ebdb3cd7805f761e8fb953aca15333d04550ef9fc2870d9b8961db' ;;
        1.131.0:linux-386) printf '%s\n' 'b2231ddbad100bd769e5d49d180b99b83365435238a963b501adc249775af25f' ;;
        1.131.0:linux-ppc64le) printf '%s\n' 'c08225b84ab5857e3bfca90bb6f59ab4cfc3ca825c4465be1683477deb501099' ;;
        1.131.0:linux-s390x) printf '%s\n' 'e6a430579dc0e2b3969dda108a46c0ccd99d81277a5e12ae3913b694eed075e5' ;;
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
    echo "Looking up the latest glab release..."
    VERSION="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest" \
        | grep -o '"tag_name":"[^"]*"' \
        | head -n 1 \
        | cut -d'"' -f4 \
        | sed 's/^v//')"

    if [ -z "${VERSION}" ]; then
        echo "Could not determine the latest glab version." >&2
        exit 1
    fi
fi
VERSION="${VERSION#v}"

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="amd64"
        ;;
    aarch64 | arm64)
        ARCH="arm64"
        ;;
    armv7l | armv6l | arm)
        ARCH="armv6"
        ;;
    i386 | i686 | 386)
        ARCH="386"
        ;;
    ppc64le)
        ARCH="ppc64le"
        ;;
    s390x)
        ARCH="s390x"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

DOWNLOAD_URL="https://gitlab.com/gitlab-org/cli/-/releases/v${VERSION}/downloads/glab_${VERSION}_linux_${ARCH}.tar.gz"

echo "Installing glab ${VERSION} for linux-${ARCH}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/glab.tar.gz" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/glab.tar.gz" "glab" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

tar -xzf "${TMP_DIR}/glab.tar.gz" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/bin/glab" ]; then
    echo "Unexpected glab archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "${TMP_DIR}/bin/glab" /usr/local/bin/glab 2>/dev/null \
    || {
        cp "${TMP_DIR}/bin/glab" /usr/local/bin/glab
        chmod 0755 /usr/local/bin/glab
    }

/usr/local/bin/glab --version
