#!/usr/bin/env bash
set -euo pipefail

INSTALL_PACKAGES="${INSTALL:-}"
REMOVE_PACKAGES="${REMOVE:-}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

PACKAGE_MANAGER=""
PARSED_PACKAGES=()
PACKAGES_TO_INSTALL=()
PACKAGES_TO_REMOVE=()

parse_packages() {
    local raw="$1"
    local pkg

    PARSED_PACKAGES=()
    while IFS= read -r pkg; do
        [ -n "${pkg}" ] || continue

        # Keep specs such as "pkg=1.2" (apt) and "pkg-1.2" (yum) usable while
        # rejecting anything that could be interpreted as shell syntax.
        case "${pkg}" in
            [A-Za-z0-9]*) ;;
            *)
                echo "Invalid package name: '${pkg}'." >&2
                return 1
                ;;
        esac
        case "${pkg}" in
            *[!A-Za-z0-9._+~:@=-]*)
                echo "Invalid package name: '${pkg}'." >&2
                return 1
                ;;
        esac

        PARSED_PACKAGES+=("${pkg}")
    done < <(printf '%s\n' "${raw}" | tr ', \t\r\n' '\n\n\n\n\n')
}

select_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    else
        echo "Unsupported package manager. This Feature supports apt (apt-get) and yum." >&2
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
        yum)
            yum -y makecache
            ;;
    esac
}

remove_packages() {
    if [ "${#PACKAGES_TO_REMOVE[@]}" -eq 0 ]; then
        return
    fi

    echo "Removing packages: ${PACKAGES_TO_REMOVE[*]}"
    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get remove -y "${PACKAGES_TO_REMOVE[@]}"
            ;;
        yum)
            yum remove -y "${PACKAGES_TO_REMOVE[@]}"
            ;;
    esac
}

install_packages() {
    if [ "${#PACKAGES_TO_INSTALL[@]}" -eq 0 ]; then
        return
    fi

    echo "Installing packages: ${PACKAGES_TO_INSTALL[*]}"
    case "${PACKAGE_MANAGER}" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                "${PACKAGES_TO_INSTALL[@]}"
            ;;
        yum)
            yum install -y "${PACKAGES_TO_INSTALL[@]}"
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
        yum)
            yum clean all
            rm -rf /var/cache/yum/* /var/cache/dnf/*
            ;;
    esac
}

parse_packages "${INSTALL_PACKAGES}"
if [ "${#PARSED_PACKAGES[@]}" -gt 0 ]; then
    PACKAGES_TO_INSTALL=("${PARSED_PACKAGES[@]}")
fi

parse_packages "${REMOVE_PACKAGES}"
if [ "${#PARSED_PACKAGES[@]}" -gt 0 ]; then
    PACKAGES_TO_REMOVE=("${PARSED_PACKAGES[@]}")
fi

if [ "${#PACKAGES_TO_INSTALL[@]}" -eq 0 ] && [ "${#PACKAGES_TO_REMOVE[@]}" -eq 0 ]; then
    echo "No packages requested; nothing to do."
    exit 0
fi

select_package_manager
update_package_cache
remove_packages
install_packages
cleanup_package_cache

echo "Package management complete."
