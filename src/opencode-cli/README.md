# OpenCode CLI

Installs the [OpenCode 2](https://opencode.ai/docs) CLI from the official npm platform packages.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | OpenCode 2 version to install, for example `2.3.2`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/opencode-cli:0": {
            "version": "latest"
        }
    }
}
```

Both `opencode` and the `opencode2` alias are installed into `/usr/local/bin`.

## Notes

- This Feature installs **OpenCode 2** (the `@opencode/cli` package line). OpenCode 1 (`opencode-ai`) is not supported.
- Linux `x64` and `arm64` are supported, including musl-based distributions such as Alpine. On x64 CPUs without AVX2, the baseline build is selected automatically.
- To keep config, credentials, and sessions across rebuilds, pair this Feature with [`opencode-persistence`](../opencode-persistence).

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/opencode-cli:0": {
            "version": "2.3.2",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f opencode-cli -i debian:trixie --project-folder .
```
