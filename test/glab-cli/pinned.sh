#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'glab --version | grep -q "glab 1.131.0"'

reportResults
