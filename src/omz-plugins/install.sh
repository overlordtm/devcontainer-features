#!/usr/bin/env bash
# Manage the Oh My Zsh "plugins=..." assignment in the remote user's .zshrc.
set -euo pipefail

FEATURE_ID="omz-plugins"
ADD_PLUGINS="${ADD:-}"
REMOVE_PLUGINS="${REMOVE:-}"
SET_PLUGINS="${SET:-}"
TMP_FILE=""

cleanup() {
    if [ -n "${TMP_FILE}" ]; then
        rm -f "${TMP_FILE}"
    fi
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root. Use sudo, su, or add \"USER root\" to your Dockerfile before running this script." >&2
    exit 1
fi

if [ -n "${SET_PLUGINS}" ] && { [ -n "${ADD_PLUGINS}" ] || [ -n "${REMOVE_PLUGINS}" ]; }; then
    echo "The 'set' option is exclusive and cannot be combined with 'add' or 'remove'." >&2
    exit 1
fi

# Keep a copy of this script so it can be re-run from inside the container (and
# so the Feature's tests can exercise the option handling directly).
install_self() {
    local target_dir="/usr/local/share/${FEATURE_ID}"
    local target="${target_dir}/install.sh"
    local source

    source="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
    [ -f "${source}" ] || return 0
    [ "${source}" = "${target}" ] && return 0

    mkdir -p "${target_dir}"
    cp "${source}" "${target}.tmp"
    chmod 0755 "${target}.tmp"
    mv -f "${target}.tmp" "${target}"
}

install_self

if [ -z "${ADD_PLUGINS}" ] && [ -z "${REMOVE_PLUGINS}" ] && [ -z "${SET_PLUGINS}" ]; then
    echo "No plugin changes requested; nothing to do."
    exit 0
fi

validate_plugin_name() {
    case "$1" in
        [A-Za-z0-9]*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        *[!A-Za-z0-9._+@-]*) return 1 ;;
    esac
}

# Turn a comma/space separated option into one validated plugin name per line.
normalize_plugins() {
    local input="$1"
    local plugin

    printf '%s\n' "${input}" \
        | tr ', \t\r\n' '\n\n\n\n\n' \
        | while IFS= read -r plugin; do
            [ -n "${plugin}" ] || continue
            if ! validate_plugin_name "${plugin}"; then
                echo "Invalid plugin name '${plugin}'. Plugin names may contain letters, numbers, '.', '_', '+', '@', and '-'." >&2
                return 1
            fi
            printf '%s\n' "${plugin}"
        done
}

read_lines() {
    local -n target="$1"
    local data="$2"
    local line

    target=()
    while IFS= read -r line; do
        [ -n "${line}" ] || continue
        target+=("${line}")
    done <<< "${data}"
}

append_unique() {
    local -n target="$1"
    local value="$2"
    local item

    for item in "${target[@]}"; do
        if [ "${item}" = "${value}" ]; then
            return 0
        fi
    done
    target+=("${value}")
}

# Print the plugin entries of every plugins=(...) assignment, one per line.
# Handles both one-line and multi-line assignments, and ignores comments.
extract_plugins() {
    awk '
        function add_entries(text,    n, parts, i, token) {
            sub(/#.*/, "", text)
            gsub(/[\047()"]/, " ", text)
            n = split(text, parts, /[[:space:]]+/)
            for (i = 1; i <= n; i++) {
                token = parts[i]
                if (token != "") {
                    print token
                }
            }
        }

        {
            if (in_plugins) {
                if (match($0, /\)/)) {
                    add_entries(substr($0, 1, RSTART - 1))
                    in_plugins = 0
                } else {
                    add_entries($0)
                }
                next
            }

            if ($0 ~ /^[[:space:]]*plugins[[:space:]]*=/) {
                rest = $0
                sub(/^[[:space:]]*plugins[[:space:]]*=/, "", rest)
                if (match(rest, /\(/)) {
                    rest = substr(rest, RSTART + 1)
                    if (match(rest, /\)/)) {
                        add_entries(substr(rest, 1, RSTART - 1))
                    } else {
                        add_entries(rest)
                        in_plugins = 1
                    }
                } else {
                    add_entries(rest)
                }
            }
        }
    ' "$1"
}

# Replace the first plugins assignment with a single canonical line and remove
# any additional ones. All other .zshrc content is left untouched.
rewrite_plugins() {
    local file="$1"
    local new_line="$2"
    local mode owner

    TMP_FILE=""
    mode="$(stat -c '%a' "${file}")"
    owner="$(stat -c '%u:%g' "${file}")"
    TMP_FILE="$(mktemp "${file}.XXXXXX")"

    awk -v new_line="${new_line}" '
        BEGIN {
            emitted = 0
            in_plugins = 0
        }

        {
            if (in_plugins) {
                if (match($0, /\)/)) {
                    in_plugins = 0
                }
                next
            }

            if ($0 ~ /^[[:space:]]*plugins[[:space:]]*=/) {
                if (!emitted) {
                    print new_line
                    emitted = 1
                }
                rest = $0
                sub(/^[[:space:]]*plugins[[:space:]]*=/, "", rest)
                if (match(rest, /\(/) && !match(substr(rest, RSTART + 1), /\)/)) {
                    in_plugins = 1
                }
                next
            }

            print
        }

        END {
            if (!emitted) {
                print new_line
            }
        }
    ' "${file}" > "${TMP_FILE}"

    chmod "${mode}" "${TMP_FILE}"
    chown "${owner}" "${TMP_FILE}"
    mv -f "${TMP_FILE}" "${file}"
    TMP_FILE=""
}

ensure_trailing_newline() {
    local file="$1"

    [ -s "${file}" ] || return 0
    if [ "$(tail -c 1 "${file}" | wc -l)" -eq 0 ]; then
        printf '\n' >> "${file}"
    fi
}

ADD_LIST="$(normalize_plugins "${ADD_PLUGINS}")"
REMOVE_LIST="$(normalize_plugins "${REMOVE_PLUGINS}")"
SET_LIST="$(normalize_plugins "${SET_PLUGINS}")"

if [ -n "${SET_PLUGINS}" ] && [ -z "${SET_LIST}" ]; then
    echo "The 'set' option did not contain any plugin names." >&2
    exit 1
fi

if [ -z "${ADD_LIST}" ] && [ -z "${REMOVE_LIST}" ] && [ -z "${SET_LIST}" ]; then
    echo "No plugin changes requested; nothing to do."
    exit 0
fi

read_lines ADD_ARR "${ADD_LIST}"
read_lines REMOVE_ARR "${REMOVE_LIST}"
read_lines SET_ARR "${SET_LIST}"

USER_NAME="${_REMOTE_USER:-root}"
USER_GROUP="$(id -gn "${USER_NAME}" 2>/dev/null || true)"
USER_HOME="${_REMOTE_USER_HOME:-}"
if [ -z "${USER_HOME}" ]; then
    USER_HOME="$(getent passwd "${USER_NAME}" 2>/dev/null | cut -d: -f6 || true)"
fi
if [ -z "${USER_HOME}" ]; then
    USER_HOME="/root"
fi

chown_user() {
    if [ -n "${USER_GROUP}" ]; then
        chown "${USER_NAME}:${USER_GROUP}" "$@"
    else
        chown "${USER_NAME}" "$@"
    fi
}

if [ ! -d "${USER_HOME}" ]; then
    mkdir -p "${USER_HOME}"
    chown_user "${USER_HOME}" 2>/dev/null || true
fi

ZSHRC="${USER_HOME}/.zshrc"
if [ -L "${ZSHRC}" ]; then
    RESOLVED_ZSHRC="$(readlink -f "${ZSHRC}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_ZSHRC}" ]; then
        ZSHRC="${RESOLVED_ZSHRC}"
    fi
fi
ZSHRC_DIR="$(dirname "${ZSHRC}")"
mkdir -p "${ZSHRC_DIR}"

HAS_PLUGINS_LINE=0
if [ -f "${ZSHRC}" ] && grep -Eq '^[[:space:]]*plugins[[:space:]]*=' "${ZSHRC}"; then
    HAS_PLUGINS_LINE=1
fi

# A remove-only request should not create or extend a .zshrc that has no
# plugins assignment to edit.
if [ "${HAS_PLUGINS_LINE}" -eq 0 ] && [ -z "${ADD_LIST}" ] && [ -z "${SET_LIST}" ]; then
    echo "No plugins= line found in ${ZSHRC}; nothing to remove."
    exit 0
fi

EXISTING_LIST=""
if [ "${HAS_PLUGINS_LINE}" -eq 1 ]; then
    EXISTING_LIST="$(extract_plugins "${ZSHRC}")"
fi

read_lines EXISTING_ARR "${EXISTING_LIST}"
for plugin in "${EXISTING_ARR[@]}"; do
    if ! validate_plugin_name "${plugin}"; then
        echo "Unsupported plugin entry '${plugin}' in ${ZSHRC}; fix the plugins= line manually and rebuild." >&2
        exit 1
    fi
done

FINAL=()
if [ -n "${SET_LIST}" ]; then
    for plugin in "${SET_ARR[@]}"; do
        append_unique FINAL "${plugin}"
    done
else
    for plugin in "${EXISTING_ARR[@]}"; do
        skip=0
        for removed in "${REMOVE_ARR[@]}"; do
            if [ "${plugin}" = "${removed}" ]; then
                skip=1
                break
            fi
        done
        if [ "${skip}" -eq 0 ]; then
            append_unique FINAL "${plugin}"
        fi
    done
    for plugin in "${ADD_ARR[@]}"; do
        append_unique FINAL "${plugin}"
    done
fi

NEW_LINE="plugins=("
for index in "${!FINAL[@]}"; do
    if [ "${index}" -gt 0 ]; then
        NEW_LINE="${NEW_LINE} "
    fi
    NEW_LINE="${NEW_LINE}${FINAL[${index}]}"
done
NEW_LINE="${NEW_LINE})"

if [ "${HAS_PLUGINS_LINE}" -eq 1 ]; then
    rewrite_plugins "${ZSHRC}" "${NEW_LINE}"
    echo "Updated ${ZSHRC}: ${NEW_LINE}"
else
    if [ ! -e "${ZSHRC}" ]; then
        : > "${ZSHRC}"
        chown_user "${ZSHRC}"
    fi
    ensure_trailing_newline "${ZSHRC}"
    printf '%s\n' "${NEW_LINE}" >> "${ZSHRC}"
    echo "Added ${NEW_LINE} to ${ZSHRC}"
fi

echo "Finished configuring ${FEATURE_ID:-omz-plugins}"
