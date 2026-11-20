# Claude Code CLI

Installs the [Claude Code](https://code.claude.com/docs) CLI from Anthropic's official native releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `latest`, `stable`, or an exact version such as `2.1.329`. |

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

The native binary is installed system-wide at `/usr/local/bin/claude`. Downloads are verified against the checksum in Anthropic's release manifest.

## Notes

- Supports Linux `x64` and `arm64`, including musl-based distributions such as Alpine.
- Adds the `anthropic.claude-code` VS Code extension customization.
- Background auto-updates are disabled with `DISABLE_AUTOUPDATER=1` so the version installed during the image build stays reproducible.
- To persist login, settings, and session history across rebuilds, pair this Feature with [`claude-code-persistence`](../claude-code-persistence).

## Testing

```bash
devcontainer features test -f claude-code -i debian:trixie --project-folder .
```
