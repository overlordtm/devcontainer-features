# uv CLI (`uv`)

Installs the [uv](https://github.com/astral-sh/uv) Python package and project manager CLI from official GitHub releases. The archive provides both the `uv` and `uvx` binaries.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `0.13.9` | uv version to install, for example `0.13.9`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/uv-cli:0": {
            "version": "0.13.9"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/arm/v6` (musl only), `linux/386`, `linux/ppc64le` (glibc only), `linux/riscv64`, and `linux/s390x` (glibc only).
- Glibc and musl targets are selected automatically, including on Alpine.
- `uv` and `uvx` are installed as `/usr/local/bin/uv` and `/usr/local/bin/uvx`.
- uv manages Python interpreters itself. Run `uv python install` to install one; this Feature only installs the uv binaries.
- `version` defaults to the pinned release `0.13.9` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the artifact digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/uv-cli:0": {
            "version": "0.13.9",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f uv-cli -i debian:trixie --project-folder .
```
