#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'opencode --version | grep -q "v2.3.2"'

reportResults
