#!/bin/bash
set -e

source dev-container-features-test-lib

check "a supported package manager is available" bash -c 'command -v apt-get >/dev/null 2>&1 || command -v apk >/dev/null 2>&1'

reportResults
