#!/bin/bash
set -e

source dev-container-features-test-lib

check "fj is installed" command -v fj
check "fj runs" bash -c 'fj version | grep -q "^fj v"'

reportResults
