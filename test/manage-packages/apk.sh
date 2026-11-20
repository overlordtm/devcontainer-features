#!/bin/bash
set -e

source dev-container-features-test-lib

check "tree is installed" command -v tree
check "tree runs" bash -c 'tree --version'
check "unzip is installed" command -v unzip
check "bash is installed" command -v bash
# The Alpine image's /etc/apk/world lists libc-utils even though that package no
# longer exists, which otherwise makes apk refuse to delete musl-utils.
check "musl-utils was removed" bash -c '! apk info -e musl-utils >/dev/null 2>&1'
check "libc-utils world entry was removed" bash -c '! grep -qx libc-utils /etc/apk/world'
check "apk metadata cache was cleaned" bash -c '[ -z "$(find /var/cache/apk -mindepth 1 -maxdepth 1 2>/dev/null)" ]'
check "apk still works" apk --version

reportResults
