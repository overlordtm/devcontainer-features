#!/bin/sh
set -eu

INSTALL_PACKAGES="${INSTALL:-}"
REMOVE_PACKAGES="${REMOVE:-}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

PACKAGE_MANAGER=""
PACKAGES_TO_INSTALL=""
PACKAGES_TO_REMOVE=""

# Normalizes a comma/space separated list into one validated package per line.
normalize_packages() {
    printf '%s\n' "$1" | tr ', \t\r\n' '\n\n\n\n\n' | while IFS= read -r pkg; do
        [ -n "${pkg}" ] || continue

        # Keep version specs such as "pkg=1.2" usable while rejecting anything
        # that could be interpreted as shell syntax.
        case "${pkg}" in
            [A-Za-z0-9]*) ;;
            *)
                echo "Invalid package name: '${pkg}'." >&2
                exit 1
                ;;
        esac
        case "${pkg}" in
            *[!A-Za-z0-9._+~:@=-]*)
                echo "Invalid package name: '${pkg}'." >&2
                exit 1
                ;;
        esac

        printf '%s\n' "${pkg}"
    done
}

select_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v apk >/dev/null 2>&1; then
        PACKAGE_MANAGER="apk"
    else
        echo "Unsupported package manager. This Feature supports apt (apt-get) and apk." >&2
        exit 1
    fi
    echo "Using ${PACKAGE_MANAGER} package manager."
}

update_package_cache() {
    echo "Updating ${PACKAGE_MANAGER} package cache..."
    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get update -y
            ;;
        apk)
            apk update
            ;;
    esac
}

remove_packages() {
    if [ -z "${PACKAGES_TO_REMOVE}" ]; then
        return 0
    fi

    echo "Removing packages:"
    # shellcheck disable=SC2086
    printf '  %s\n' ${PACKAGES_TO_REMOVE}

    OLD_IFS="${IFS}"
    IFS='
'
    set -f
    # shellcheck disable=SC2086
    set -- ${PACKAGES_TO_REMOVE}
    IFS="${OLD_IFS}"
    set +f

    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
            ;;
        apk)
            apk del "$@"
            ;;
    esac
}

install_packages() {
    if [ -z "${PACKAGES_TO_INSTALL}" ]; then
        return 0
    fi

    echo "Installing packages:"
    # shellcheck disable=SC2086
    printf '  %s\n' ${PACKAGES_TO_INSTALL}

    OLD_IFS="${IFS}"
    IFS='
'
    set -f
    # shellcheck disable=SC2086
    set -- ${PACKAGES_TO_INSTALL}
    IFS="${OLD_IFS}"
    set +f

    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
            ;;
        apk)
            apk add "$@"
            ;;
    esac
}

cleanup_package_cache() {
    echo "Cleaning ${PACKAGE_MANAGER} package cache..."
    case "${PACKAGE_MANAGER}" in
        apt)
            apt-get clean
            rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb
            ;;
        apk)
            apk cache clean || true
            rm -rf /var/cache/apk/*
            ;;
    esac
}

PACKAGES_TO_INSTALL="$(normalize_packages "${INSTALL_PACKAGES}")"
PACKAGES_TO_REMOVE="$(normalize_packages "${REMOVE_PACKAGES}")"

if [ -z "${PACKAGES_TO_INSTALL}" ] && [ -z "${PACKAGES_TO_REMOVE}" ]; then
    echo "No packages requested; nothing to do."
    exit 0
fi

select_package_manager
update_package_cache
remove_packages
install_packages
cleanup_package_cache

echo "Package management complete."
