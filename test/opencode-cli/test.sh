#!/bin/bash
set -e

source dev-container-features-test-lib

check "opencode is installed" command -v opencode
check "opencode2 alias is installed" command -v opencode2
check "opencode runs" bash -c 'opencode --version | grep -q "^opencode v2\."'
check "opencode2 alias runs" bash -c 'opencode2 --version | grep -q "^opencode v2\."'

reportResults
