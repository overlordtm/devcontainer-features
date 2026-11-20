#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.13.9}"
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
        0.13.9:x86_64-unknown-linux-gnu) printf '%s\n' 'a7fbaff2b9a271d85c1bdb540941090fd1ce011797b4abeb48e4dcd39c2471d5' ;;
        0.13.9:x86_64-unknown-linux-musl) printf '%s\n' '58ccf5f1792b8a5a88d01bc910ea131a8b3db4a319a17ad5fad75e0845a3e271' ;;
        0.13.9:aarch64-unknown-linux-gnu) printf '%s\n' '0797542018e541a9288855df555c8077eed06f7a47d206362030480e8ecc9f3d' ;;
        0.13.9:aarch64-unknown-linux-musl) printf '%s\n' '37fbb7c5bc66cf99c12aa881949d216181e201dec449772c4329e56487d61179' ;;
        0.13.9:armv7-unknown-linux-gnueabihf) printf '%s\n' '8bd2ce216e6d3fe825ec0fde4532dea708964e8c419844d2ed8e9e7901a7a11e' ;;
        0.13.9:armv7-unknown-linux-musleabihf) printf '%s\n' '477c4d3759aaf68d76e570da03438d80a6445118e2a3d74500a98144c54324db' ;;
        0.13.9:arm-unknown-linux-musleabihf) printf '%s\n' 'b43b18e668c94f60e39fb91994cd5b4f17474f81d4967039071afb8f18a6b72d' ;;
        0.13.9:i686-unknown-linux-gnu) printf '%s\n' 'ef1d3f7464e650d639f41f10130b2d9cb06d4171dd9778beb7f93a6d498812c5' ;;
        0.13.9:i686-unknown-linux-musl) printf '%s\n' '0fc2dc2355d4d9c8b3695c3a0aedeb6d62ef921e6e78db1bbc0ff32857b944b7' ;;
        0.13.9:powerpc64le-unknown-linux-gnu) printf '%s\n' '5c074a4a008037787c665081116b5b7bc77161d1b5b47ca936732f84b498b317' ;;
        0.13.9:riscv64gc-unknown-linux-gnu) printf '%s\n' '96543eb42d59426db0092f1d860f319abb87c83aaa413a9710108cbd4f68c34b' ;;
        0.13.9:riscv64gc-unknown-linux-musl) printf '%s\n' '0cf8c79c766dcbbc641e2a40f7433491c279a5b39869d6138bcd1c71adf82f93' ;;
        0.13.9:s390x-unknown-linux-gnu) printf '%s\n' '7e15c75fbd907334790d60037e492877ed053dff82cc1c0e2a1de0825d0d3864' ;;
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
    echo "Looking up the latest uv release..."
    if ! VERSION="$(resolve_latest_version "astral-sh/uv")"; then
        echo "Could not determine the latest uv version." >&2
        echo "Set the 'version' option to a specific release (for example \"0.13.9\") to skip the lookup." >&2
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
        echo "Unsupported architecture: $(uname -m). uv publishes Linux builds for x86_64, aarch64, armv7, arm, i686, powerpc64le, riscv64gc, and s390x." >&2
        exit 1
        ;;
esac

LIBC="$(detect_libc)"

case "${ARCH}" in
    x86_64 | aarch64 | i686 | riscv64gc)
        TARGET="${ARCH}-unknown-linux-${LIBC}"
        ;;
    armv7)
        TARGET="armv7-unknown-linux-${LIBC}eabihf"
        ;;
    arm)
        if [ "${LIBC}" != "musl" ]; then
            echo "Unsupported libc for ${ARCH}: uv only publishes musl builds for this architecture." >&2
            exit 1
        fi
        TARGET="arm-unknown-linux-musleabihf"
        ;;
    powerpc64le | s390x)
        if [ "${LIBC}" != "gnu" ]; then
            echo "Unsupported libc for ${ARCH}: uv only publishes glibc builds for this architecture." >&2
            exit 1
        fi
        TARGET="${ARCH}-unknown-linux-gnu"
        ;;
    *)
        echo "Unsupported architecture: ${ARCH}." >&2
        exit 1
        ;;
esac

TARBALL_NAME="uv-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/astral-sh/uv/releases/download/${VERSION}/${TARBALL_NAME}"

echo "Installing uv ${VERSION} for ${TARGET}..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL --retry 3 --retry-delay 2 -o "${TMP_DIR}/${TARBALL_NAME}" "${DOWNLOAD_URL}"

if ! verify_download "${TMP_DIR}/${TARBALL_NAME}" "uv" "${VERSION}" "${TARGET}"; then
    exit 1
fi

tar -xzf "${TMP_DIR}/${TARBALL_NAME}" -C "${TMP_DIR}"

if [ ! -f "${TMP_DIR}/uv-${TARGET}/uv" ]; then
    echo "Unexpected uv archive layout." >&2
    exit 1
fi

mkdir -p /usr/local/bin
for binary in uv uvx; do
    source="${TMP_DIR}/uv-${TARGET}/${binary}"
    if [ ! -f "${source}" ]; then
        continue
    fi
    install -m 0755 "${source}" "/usr/local/bin/${binary}" 2>/dev/null \
        || {
            cp "${source}" "/usr/local/bin/${binary}"
            chmod 0755 "/usr/local/bin/${binary}"
        }
done

/usr/local/bin/uv --version
/usr/local/bin/uvx --version
