# Claude Code CLI

Installs the [Claude Code](https://code.claude.com/docs) CLI from Anthropic's official native releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `latest`, `stable`, or an exact version such as `2.1.329`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/claude-code:0": {
            "version": "latest"
        }
    }
}
```

The native binary is installed system-wide at `/usr/local/bin/claude`.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. The hash is computed over the decompressed `claude` binary.

If `latest` or `stable` resolves to a version that is not in the map, the build fails unless you provide a digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/claude-code:0": {
            "version": "2.1.329",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Notes

- Supports Linux `x64` and `arm64`, including musl-based distributions such as Alpine.
- Adds the `anthropic.claude-code` VS Code extension customization.
- Background auto-updates are disabled with `DISABLE_AUTOUPDATER=1` so the version installed during the image build stays reproducible.
- To persist login, settings, and session history across rebuilds, pair this Feature with [`claude-code-persistence`](../claude-code-persistence).

## Testing

```bash
devcontainer features test -f claude-code -i debian:trixie --project-folder .
```
