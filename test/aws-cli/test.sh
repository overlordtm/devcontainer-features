#!/bin/bash
set -e

source dev-container-features-test-lib

check "aws is installed" command -v aws
check "aws runs" bash -c 'aws --version | grep -q "^aws-cli/"'
check "default version is pinned" bash -c 'aws --version | grep -q "aws-cli/2.42.0"'
check "aws_completer is installed" command -v aws_completer

reportResults
