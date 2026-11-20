#!/bin/bash
set -e

source dev-container-features-test-lib

check "glab is installed" command -v glab
check "glab runs" bash -c 'glab --version | grep -q "^glab "'
check "default version is pinned" bash -c 'glab --version | grep -q "glab 1.131.0"'

reportResults
