#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'tofu version | grep -q "OpenTofu v1.13.9"'

reportResults
