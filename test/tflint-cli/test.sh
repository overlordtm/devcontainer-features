#!/bin/bash
set -e

source dev-container-features-test-lib

check "tflint is installed" command -v tflint
check "tflint runs" bash -c 'tflint --version | grep -q "^TFLint version "'
check "default version is pinned" bash -c 'tflint --version | grep -q "TFLint version 0.66.0"'

reportResults
