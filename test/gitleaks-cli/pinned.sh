#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'gitleaks version | grep -q "8.30.1"'

reportResults
