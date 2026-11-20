#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'aws --version | grep -q "aws-cli/2.42.0"'

reportResults
