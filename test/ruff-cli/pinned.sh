#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'ruff --version | grep -q "0.17.6"'

reportResults
