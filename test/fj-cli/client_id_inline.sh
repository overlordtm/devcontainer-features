#!/bin/bash
set -e

source dev-container-features-test-lib

check "client id mapping is written" grep -Fx "forge.example.com 00112233-4455-6677-8899-aabbccddeeff" /etc/fj/client_ids

reportResults
