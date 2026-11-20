#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'sops --version | grep -q "sops 3.13.3"'

reportResults
