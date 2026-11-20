#!/bin/bash
set -e

source dev-container-features-test-lib

check "tree is installed" command -v tree
check "tree runs" bash -c 'tree --version'
check "unzip is installed" command -v unzip
check "less was removed" bash -c '! rpm -q less >/dev/null 2>&1'
check "yum metadata cache was cleaned" bash -c '[ -z "$(find /var/cache/yum /var/cache/dnf -mindepth 1 -maxdepth 1 2>/dev/null)" ]'
check "yum still works" yum --version

reportResults
