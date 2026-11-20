# OpenCode CLI

Installs the [OpenCode 2](https://opencode.ai/docs) CLI from the official npm platform packages.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | OpenCode 2 version to install, for example `2.3.2`. |

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

## Testing

```bash
devcontainer features test -f opencode-cli -i debian:trixie --project-folder .
```
