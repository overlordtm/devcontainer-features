# GitHub CLI (`gh`)

Installs the [GitHub CLI](https://github.com/cli/cli) from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `2.105.0` | `gh` version to install, for example `2.105.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gh-cli:0": {
            "version": "2.105.0"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/arm/v6` (which also runs on `arm/v7`), and `linux/386`.
- `gh` is installed as `/usr/local/bin/gh`. The release tarball's man pages are not installed.
- `gh` stores authentication and configuration in `~/.config/gh`, extensions in `~/.local/share/gh`, and update state in `~/.local/state/gh`. This Feature does not persist those directories; pair it with [`gh-cli-persistence`](../gh-cli-persistence) to keep logins across rebuilds.
- `version` defaults to the pinned release `2.105.0` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gh-cli:0": {
            "version": "2.105.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f gh-cli -i debian:trixie --project-folder .
```
