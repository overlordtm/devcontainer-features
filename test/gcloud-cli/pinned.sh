#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'gcloud --version | grep -q "Google Cloud SDK 594.0.0"'

reportResults
