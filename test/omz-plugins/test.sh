#!/bin/bash
set -e

source dev-container-features-test-lib

SCRIPT="/usr/local/share/omz-plugins/install.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

check "install script is available for re-use" test -x "${SCRIPT}"

# The installed script must run as root, just like Feature installation.
if [ "$(id -u)" -eq 0 ]; then
    check "no options leaves .zshrc alone" bash -c '
        home="$1"
        script="$2"
        mkdir -p "$home"
        env -u ADD -u REMOVE -u SET _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$home" "$script" >/dev/null
        test ! -e "$home/.zshrc"
    ' _ "${TEST_ROOT}/noop" "${SCRIPT}"

    check "add keeps existing plugins and ignores duplicates" bash -c '
        home="$1"
        script="$2"
        mkdir -p "$home"
        printf "%s\n" "plugins=(git docker)" > "$home/.zshrc"
        env -u ADD -u REMOVE -u SET _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$home" \
            ADD="zsh-autosuggestions, docker" "$script" >/dev/null
        grep -qxF "plugins=(git docker zsh-autosuggestions)" "$home/.zshrc"
    ' _ "${TEST_ROOT}/add" "${SCRIPT}"

    check "remove deletes only the requested plugins" bash -c '
        home="$1"
        script="$2"
        mkdir -p "$home"
        printf "%s\n" "plugins=(git docker kubectl)" > "$home/.zshrc"
        env -u ADD -u REMOVE -u SET _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$home" \
            REMOVE="docker missing-plugin" "$script" >/dev/null
        grep -qxF "plugins=(git kubectl)" "$home/.zshrc"
    ' _ "${TEST_ROOT}/remove" "${SCRIPT}"

    check "set replaces the whole plugin list" bash -c '
        home="$1"
        script="$2"
        mkdir -p "$home"
        printf "%s\n" "plugins=(git docker)" > "$home/.zshrc"
        env -u ADD -u REMOVE -u SET _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$home" \
            SET="zsh-autosuggestions git" "$script" >/dev/null
        grep -qxF "plugins=(zsh-autosuggestions git)" "$home/.zshrc"
    ' _ "${TEST_ROOT}/set" "${SCRIPT}"

    check "set cannot be combined with add or remove" bash -c '
        home="$1"
        script="$2"
        mkdir -p "$home"
        printf "%s\n" "plugins=(git)" > "$home/.zshrc"
        if env -u ADD -u REMOVE -u SET _REMOTE_USER="$(id -un)" _REMOTE_USER_HOME="$home" \
            SET="docker" ADD="git" "$script" >/dev/null 2>&1; then
            exit 1
        fi
        grep -qxF "plugins=(git)" "$home/.zshrc"
    ' _ "${TEST_ROOT}/exclusive" "${SCRIPT}"
fi

reportResults
