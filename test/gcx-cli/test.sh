#!/bin/bash
set -e

source dev-container-features-test-lib

check "gcx is installed" command -v gcx
check "gcx runs" bash -c 'gcx --version | grep -q "^gcx version "'
check "default version is pinned" bash -c 'gcx --version | grep -q "gcx version 1.8.0"'

reportResults
