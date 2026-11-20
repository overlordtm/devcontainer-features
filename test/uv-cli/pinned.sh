#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'uv --version | grep -q "0.13.9"'
check "pinned uvx is installed" bash -c 'uvx --version | grep -q "0.13.9"'

reportResults
