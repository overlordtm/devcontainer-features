# Go (`go`)

Installs the [Go](https://go.dev) programming language toolchain from official upstream release archives, following the [official install instructions](https://go.dev/doc/install). It does not use distribution packages.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `1.27.4` | Go version to install, for example `1.27.4`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/go:0": {
            "version": "1.27.4"
        }
    }
}
```

## Notes

- Supports the Linux architectures published for the release: `386`, `amd64`, `arm64`, `armv6l`, `loong64`, `mips`, `mips64`, `mips64le`, `mipsle`, `ppc64`, `ppc64le`, `riscv64`, and `s390x`.
- The toolchain is extracted to `/usr/local/go`, and `go` and `gofmt` are symlinked into `/usr/local/bin`, which is already on `PATH`.
- `GOROOT` is reported as `/usr/local/go`. The default `GOPATH` remains `$HOME/go`.
- The archive is extracted with the ownership and permissions from the upstream tarball (`root:root`).
- `version` defaults to the pinned release `1.27.4` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.
- An existing `/usr/local/go` directory is removed before extraction, as recommended by the official instructions. Binaries installed elsewhere (for example a distribution-provided Go) are not modified, but `/usr/local/bin/go` takes precedence on `PATH`.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the archive digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/go:0": {
            "version": "1.27.4",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f go -i debian:trixie --project-folder .
```
