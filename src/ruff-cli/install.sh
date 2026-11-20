#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.17.6}"
HASH_INPUT="${HASH:-auto}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# SHA-256 checksums for vetted release artifacts. Keys are
# "<version>:<target-triple>", where the target triple matches the artifact
# name used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        0.17.6:x86_64-unknown-linux-gnu) printf '%s\n' '94b33791f48cd54ab35ad673a443a5c001d3e6d87effeaba9899070b700d45f3' ;;
        0.17.6:x86_64-unknown-linux-musl) printf '%s\n' '3c8d5a4264558df8b1587ce32409b658069b6a1ef5bfe4d279431eb1db62a183' ;;
        0.17.6:aarch64-unknown-linux-gnu) printf '%s\n' 'd4eea36ee6228f6c6bbcf0aea4ebf66fe0e595eedc6cffe628d7b8ba3623390f' ;;
        0.17.6:aarch64-unknown-linux-musl) printf '%s\n' 'dc96feed20df78c9498106cd2483e710a4db8b00b13a75954b2a37bc9f61e65c' ;;
        0.17.6:armv7-unknown-linux-gnueabihf) printf '%s\n' '2bd513dd430e7758915be3a4f8192acfa884e6dac4921c5e99c7600676aabd09' ;;
        0.17.6:armv7-unknown-linux-musleabihf) printf '%s\n' '5abd6d3807282570f12eb551d800028ce87752dbbc9ce09125684024ce8a8357' ;;
        0.17.6:arm-unknown-linux-musleabihf) printf '%s\n' '69674e7609c2c914e5f91bdf70763cab64723ba2c89a894bee43e6fa7a254fe7' ;;
        0.17.6:i686-unknown-linux-gnu) printf '%s\n' '2420011b02bd27e302cf8c9eb89fcabc5fd40b160dbb92f10eb05cde01f6354d' ;;
        0.17.6:i686-unknown-linux-musl) printf '%s\n' '516e5637c5cbe3a74b433ab6cc7031c629d3b5c377d81a0187ad461184899866' ;;
        0.17.6:powerpc64le-unknown-linux-gnu) printf '%s\n' '248b5df2e1905b4651d013c526bf3ee076721b584f04fb5b42958c9b1204851f' ;;
        0.17.6:riscv64gc-unknown-linux-gnu) printf '%s\n' '5965ab6cf825f617efd7aa4a323a8df77a4530de66dad6121f6dcf28c20be7aa' ;;
        0.17.6:s390x-unknown-linux-gnu) printf '%s\n' '02f2379a522a43b5fd25648f4947e40b8491b264a64b8e67a42411c09a29bf71' ;;
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
        echo "Unsupported package manager. Please install curl, ca-certificates, and gzip manually." >&2
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
if ! command -v gzip >/dev/null 2>&1; then
    MISSING_PACKAGES="${MISSING_PACKAGES} gzip"
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
    echo "Looking up the latest Ruff release..."
    if ! VERSION="$(resolve_latest_version "astral-sh/ruff")"; then
        echo "Could not determine the latest Ruff version." >&2
        echo "Set the 'version' option to a specific release (for example \"0.17.6\") to skip the lookup." >&2
        exit 1
    fi
fi
VERSION="${VERSION#v}"

detect_libc() {
    if [ -f /etc/alpine-release ]; then
        printf '%s\n' "musl"
        return 0
    fi
    if command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
        printf '%s\n' "musl"
        return 0
    fi
    printf '%s\n' "gnu"
}

case "$(uname -m)" in
    x86_64 | amd64)
        ARCH="x86_64"
        ;;
    aarch64 | arm64)
        ARCH="aarch64"
        ;;
    armv7l | armv7)
        ARCH="armv7"
        ;;
    armv6l | armv6 | arm)
        ARCH="arm"
        ;;
    i386 | i686 | 386)
        ARCH="i686"
        ;;
    ppc64le | powerpc64le)
        ARCH="powerpc64le"
        ;;
    riscv64)
        ARCH="riscv64gc"
        ;;
    s390x)
        ARCH="s390x"
        ;;
    *)
        echo "Unsupported architecture: $(uname -m). Ruff publishes Linux builds for x86_64, aarch64, armv7, arm, i686, powerpc64le, riscv64gc, and s390x." >&2
        exit 1
        ;;
esac

LIBC="$(detect_libc)"

case "${ARCH}" in
    x86_64 | aarch64 | i686)
        TARGET="${ARCH}-unknown-linux-${LIBC}"
        ;;
    armv7)
        TARGET="armv7-unknown-linux-${LIBC}eabihf"
        ;;
    arm)
        if [ "${LIBC}" != "musl" ]; then
            echo "Unsupported libc for ${ARCH}: Ruff only publishes musl builds for this architecture." >&2
            exit 1
        fi
        TARGET="arm-unknown-linux-musleabihf"
        ;;
    riscv64gc)
        if [ "${LIBC}" != "gnu" ]; then
            echo "Unsupported libc for ${ARCH}: Ruff only publishes glibc builds for this architecture." >&2
            exit 1
        fi
        TARGET="${ARCH}-unknown-linux-gnu"
        ;;
    powerpc64le | s390x)
        if [ "${LIBC}" != "gnu" ]; then
            echo "Unsupported libc for ${ARCH}: Ruff only publishes glibc builds for this architecture." >&2
            exit 1
        fi
        TARGET="${ARCH}-unknown-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}." >&2
        exit 1
        ;;
esac

TARBALL_NAME="ruff-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/astral-sh/ruff/releases/download/${VERSION}/${TARBALL_NAME}"

echo "Installing Ruff ${VERSION} for ${TARGET}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${TARBALL_NAME}" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/${TARBALL_NAME}" "Ruff" "${VERSION}" "${TARGET}"; then
    exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL_NAME}" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/ruff-${TARGET}/ruff" ]; then
    echo "Unexpected Ruff archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
install -m 0755 "${TMP_DIR}/ruff-${TARGET}/ruff" /usr/local/bin/ruff 2>/dev/null \
    || {
        cp "${TMP_DIR}/ruff-${TARGET}/ruff" /usr/local/bin/ruff
        chmod 0755 /usr/local/bin/ruff
    }

/usr/local/bin/ruff --version
