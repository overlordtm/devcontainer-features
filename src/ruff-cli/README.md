# Ruff CLI (`ruff`)

Installs the [Ruff](https://github.com/astral-sh/ruff) Python linter and formatter CLI from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `0.17.6` | Ruff version to install, for example `0.17.6`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/ruff-cli:0": {
            "version": "0.17.6"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/arm/v7`, `linux/arm/v6` (musl only), `linux/386`, `linux/ppc64le` (glibc only), `linux/riscv64` (glibc only), and `linux/s390x` (glibc only).
- Glibc and musl targets are selected automatically, including on Alpine.
- `ruff` is installed as `/usr/local/bin/ruff`.
- Ruff reads its configuration from `pyproject.toml` or `ruff.toml` in the project; this Feature only installs the binary.
- `version` defaults to the pinned release `0.17.6` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the artifact digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/ruff-cli:0": {
            "version": "0.17.6",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f ruff-cli -i debian:trixie --project-folder .
```
