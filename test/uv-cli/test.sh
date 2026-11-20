#!/bin/bash
set -e

source dev-container-features-test-lib

check "uv is installed" command -v uv
check "uvx is installed" command -v uvx
check "uv runs" bash -c 'uv --version | grep -q "^uv "'
check "uvx runs" bash -c 'uvx --version | grep -q "^uvx "'
check "default version is pinned" bash -c 'uv --version | grep -q "0.13.9"'

reportResults
