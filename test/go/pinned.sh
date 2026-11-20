#!/bin/bash
set -e

source dev-container-features-test-lib

check "pinned version is installed" bash -c 'go version | grep -q "go1.27.4"'
check "gofmt runs" bash -c 'gofmt -h 2>&1 | grep -q "usage: gofmt"'

reportResults
