#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'age --version | grep -q "v1.3.2"'

reportResults
