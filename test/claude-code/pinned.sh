#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'claude --version | grep -q "2.1.329"'

reportResults
