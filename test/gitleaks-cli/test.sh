#!/bin/bash
set -e

source dev-container-features-test-lib

check "gitleaks is installed" command -v gitleaks
check "gitleaks runs" bash -c 'gitleaks version | grep -q "^[0-9]"'
check "default version is pinned" bash -c 'gitleaks version | grep -q "8.30.1"'

reportResults
