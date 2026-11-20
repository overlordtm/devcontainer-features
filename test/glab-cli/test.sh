#!/bin/bash
set -e

source dev-container-features-test-lib

check "glab is installed" command -v glab
check "glab runs" bash -c 'glab --version | grep -q "^glab "'

reportResults
