#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'fj version | grep -q "^fj v0.7.0"'

reportResults
