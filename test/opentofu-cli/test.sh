#!/bin/bash
set -e

source dev-container-features-test-lib

check "tofu is installed" command -v tofu
check "tofu runs" bash -c 'tofu version | grep -q "^OpenTofu v"'
check "default version is pinned" bash -c 'tofu version | grep -q "OpenTofu v1.13.9"'

reportResults
