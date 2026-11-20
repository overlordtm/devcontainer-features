# SOPS CLI (`sops`)

Installs the [SOPS](https://github.com/getsops/sops) secrets management CLI from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | sops version to install, for example `3.13.3`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/sops-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Supports `linux/amd64` and `linux/arm64`.
- `sops` is installed as `/usr/local/bin/sops`.
- sops stores its configuration in `~/.config/sops`; this Feature does not persist that directory.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the artifact digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/sops-cli:0": {
            "version": "3.13.3",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f sops-cli -i debian:trixie --project-folder .
```
