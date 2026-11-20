#!/bin/bash
set -e

source dev-container-features-test-lib

check "tree is installed" command -v tree
check "tree runs" bash -c 'tree --version'
check "unzip is installed" command -v unzip
check "gawk is installed" command -v gawk
check "mawk was removed" bash -c '! command -v mawk'
check "awk still works" bash -c 'echo test | awk "{print}" | grep -q test'
check "apt metadata cache was cleaned" bash -c '[ -z "$(find /var/lib/apt/lists -mindepth 1 -maxdepth 1 2>/dev/null)" ]'
check "apt package cache was cleaned" bash -c '! find /var/cache/apt/archives -maxdepth 1 -name "*.deb" -print -quit 2>/dev/null | grep -q .'
check "apt still works" apt-get --version

reportResults
