#!/bin/bash
set -e

source dev-container-features-test-lib

check "gitleaks is installed" command -v gitleaks
check "gitleaks runs" bash -c 'gitleaks version | grep -q "^[0-9]"'

reportResults
