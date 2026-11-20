#!/bin/bash
set -e

source dev-container-features-test-lib

check "go is installed" command -v go
check "gofmt is installed" command -v gofmt
check "go runs" bash -c 'go version | grep -q "^go version go1\.27\.4 "'
check "GOROOT is /usr/local/go" bash -c '[ "$(go env GOROOT)" = "/usr/local/go" ]'
check "go compiles and runs a program" bash -c '
    tmp="$(mktemp -d)"
    cd "${tmp}"
    go mod init example.com/hello >/dev/null 2>&1
    printf "package main\n\nimport \"fmt\"\n\nfunc main() { fmt.Println(\"hello\") }\n" > main.go
    output="$(go run .)"
    cd /
    rm -rf "${tmp}"
    [ "${output}" = "hello" ]
'

reportResults
