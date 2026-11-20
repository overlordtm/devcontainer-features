#!/bin/bash
set -e

source dev-container-features-test-lib

check "sops is installed" command -v sops
check "sops runs" bash -c 'sops --version | grep -q "^sops "'

reportResults
