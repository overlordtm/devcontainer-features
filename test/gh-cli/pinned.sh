#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'gh --version | grep -q "gh version 2.105.0"'

reportResults
