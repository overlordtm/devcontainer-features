#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'tflint --version | grep -q "TFLint version 0.66.0"'

reportResults
