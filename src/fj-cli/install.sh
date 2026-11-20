#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-0.7.0}"
HASH_INPUT="${HASH:-auto}"
CLIENT_ID="${CLIENT_ID:-}"
CLIENT_ID_STATE_DIR="/usr/local/share/fj-cli"
CLIENT_ID_STATE_FILE="${CLIENT_ID_STATE_DIR}/client_id"
CLIENT_IDS_DIR="/etc/fj"
CLIENT_IDS_FILE="${CLIENT_IDS_DIR}/client_ids"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

# fj opens URLs through xdg-open/gio (the Rust `open` crate) and ignores
# $BROWSER. There is no browser in the container, so provide a shim that
# hands the URL to the browser helper VS Code exposes through $BROWSER.
install_xdg_open_shim() {
    install -d -m 0755 /usr/local/bin
    printf '%s\n' \
        '#!/bin/sh' \
        ': "${BROWSER:?BROWSER not set (VS Code sets it in attached terminals)}"' \
        'exec "$BROWSER" "$@"' > /usr/local/bin/xdg-open
    chmod 0755 /usr/local/bin/xdg-open
}

install_xdg_open_shim

# SHA-256 checksums for vetted release artifacts. Keys are "<version>:<platform>"
# and <platform> matches the platform identifier used in the download URL.
lookup_checksum() {
    case "$1:$2" in
        0.7.0:linux-x86_64) printf '%s\n' '6803c12eed17bfadb40ba95da2a6ab58f9b4a7dc10eabfe3512fce7e2fe6216f' ;;
        0.7.0:linux-aarch64) printf '%s\n' '198987908e194704b4a350119596547bc95cd9b6518024d6d02c26f061cfce83' ;;
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

is_client_id_mapping() {
    [[ "$1" =~ ^[^[:space:]]+[[:space:]]+[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]
}

is_client_id_filename() {
    case "$1" in
        '' | . | ..) return 1 ;;
    esac
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

find_client_ids_source() {
    name="$1"

    check_dir() {
        [ -n "$1" ] || return 1
        candidate="${1%/}/.devcontainer/${name}"
        if [ -f "${candidate}" ]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
        return 1
    }

    for base in "${PWD:-}" "${containerWorkspaceFolder:-}" "${_REMOTE_USER_HOME:-}"; do
        if check_dir "${base}"; then
            return 0
        fi
    done

    # Walk up from the current directory so a build context nested below the
    # workspace (for example in the Features test harness) can be found too.
    dir="${PWD:-}"
    while [ -n "${dir}" ] && [ "${dir}" != "/" ]; do
        if check_dir "$(dirname "${dir}")"; then
            return 0
        fi
        dir="$(dirname "${dir}")"
    done

    for base in /workspaces/* /workspace /src; do
        if check_dir "${base}"; then
            return 0
        fi
    done

    return 1
}

install_client_ids() {
    value="$1"

    if is_client_id_mapping "${value}"; then
        install -d -m 0755 "${CLIENT_IDS_DIR}"
        printf '%s\n' "${value}" > "${CLIENT_IDS_FILE}"
        chmod 0644 "${CLIENT_IDS_FILE}"
        echo "Wrote OAuth client ID mapping to ${CLIENT_IDS_FILE}."
        return 0
    fi

    if ! is_client_id_filename "${value}"; then
        echo "Invalid client_id option: expected '<host> <uuid>' or a file name." >&2
        return 1
    fi

    if source_file="$(find_client_ids_source "${value}")"; then
        install -d -m 0755 "${CLIENT_IDS_DIR}"
        install -m 0644 "${source_file}" "${CLIENT_IDS_FILE}"
        echo "Copied ${source_file} to ${CLIENT_IDS_FILE}."
        return 0
    fi

    # The workspace is normally mounted only when the container starts, so the
    # file fallback is completed by oncreate.sh at that point.
    echo "client_id file '${value}' was not found under .devcontainer; it will be copied when the container starts."
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

mkdir -p "${CLIENT_ID_STATE_DIR}"
install -m 0755 "$(dirname "$0")/oncreate.sh" "${CLIENT_ID_STATE_DIR}/oncreate.sh"

if [ -n "${CLIENT_ID}" ]; then
    printf '%s\n' "${CLIENT_ID}" > "${CLIENT_ID_STATE_FILE}"
    chmod 0644 "${CLIENT_ID_STATE_FILE}"
    install_client_ids "${CLIENT_ID}"
fi

if is_musl; then
    install_with_cargo
    /usr/local/bin/fj version
    exit 0
fi

resolve_latest_version() {
    repo="$1"

    # Prefer the release page redirect; it is cheaper and not rate limited.
    if effective_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
        --retry 3 --retry-delay 2 \
        "https://codeberg.org/${repo}/releases/latest" 2>/dev/null)"; then
        tag="${effective_url##*/}"
        case "${tag}" in
            '' | latest | */* | *[!A-Za-z0-9._-]*) ;;
            *) printf '%s\n' "${tag#v}"; return 0 ;;
        esac
    fi

    # Fall back to the REST API in case the redirect could not be resolved.
    if tag="$(curl -fsSL --retry 3 --retry-delay 2 \
        "https://codeberg.org/api/v1/repos/${repo}/releases/latest" 2>/dev/null \
        | grep -o '"tag_name":"[^"]*"' \
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
    echo "Looking up the latest fj release..."
    if ! VERSION="$(resolve_latest_version "forgejo-contrib/forgejo-cli")"; then
        echo "Could not determine the latest fj version." >&2
        echo "Set the 'version' option to a specific release (for example \"0.7.0\") to skip the lookup." >&2
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

if ! verify_download "${TMP_DIR}/fj.tar.gz" "fj" "${VERSION}" "linux-${ARCH}"; then
    exit 1
fi

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
