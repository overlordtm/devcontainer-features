#!/bin/bash
set -e

source dev-container-features-test-lib

check "gcloud is installed" command -v gcloud
check "gcloud runs" bash -c 'gcloud --version | grep -q "^Google Cloud SDK "'
check "default version is pinned" bash -c 'gcloud --version | grep -q "Google Cloud SDK 594.0.0"'
check "gsutil is installed" command -v gsutil
check "bq is installed" command -v bq
check "CLOUDSDK_HOME points at the SDK" bash -c '[ "${CLOUDSDK_HOME}" = "/usr/local/lib/google-cloud-sdk" ]'

reportResults
