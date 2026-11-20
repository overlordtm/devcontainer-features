#!/bin/bash
set -e

source dev-container-features-test-lib

check "age is installed" command -v age
check "age-keygen is installed" command -v age-keygen
check "age runs" bash -c 'age --version | grep -q "^v"'
check "age-keygen runs" bash -c 'age-keygen --version | grep -q "^v"'

reportResults
