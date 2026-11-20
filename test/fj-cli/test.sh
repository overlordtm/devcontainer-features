#!/bin/bash
set -e

source dev-container-features-test-lib

check "fj is installed" command -v fj
check "fj runs" bash -c 'fj version | grep -q "^fj v"'

check "xdg-open shim is installed" test -x /usr/local/bin/xdg-open
check "xdg-open shim delegates to \$BROWSER" bash -c 'BROWSER=/bin/echo xdg-open "https://example.com" | grep -q "https://example.com"'
check "xdg-open shim explains a missing BROWSER" bash -c 'env -u BROWSER xdg-open "https://example.com" 2>&1 | grep -q "BROWSER not set"'

reportResults
