#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'gcx --version | grep -q "gcx version 1.8.0"'

reportResults
