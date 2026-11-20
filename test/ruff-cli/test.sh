#!/bin/bash
set -e

source dev-container-features-test-lib

check "ruff is installed" command -v ruff
check "ruff runs" bash -c 'ruff --version | grep -q "^ruff "'
check "default version is pinned" bash -c 'ruff --version | grep -q "0.17.6"'

reportResults
