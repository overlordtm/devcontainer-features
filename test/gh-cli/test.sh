#!/bin/bash
set -e

source dev-container-features-test-lib

check "gh is installed" command -v gh
check "gh runs" bash -c 'gh --version | grep -q "^gh version "'
check "default version is pinned" bash -c 'gh --version | grep -q "gh version 2.105.0"'

reportResults
