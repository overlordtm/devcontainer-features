# Gitleaks CLI (`gitleaks`)

Installs the [Gitleaks](https://github.com/gitleaks/gitleaks) secret scanning CLI from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `8.30.1` | gitleaks version to install, for example `8.30.1`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gitleaks-cli:0": {
            "version": "8.30.1"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/386`, `linux/arm/v6`, and `linux/arm/v7`.
- `gitleaks` is installed as `/usr/local/bin/gitleaks`.
- gitleaks reads configuration from `.gitleaks.toml` in the repository; this Feature only installs the binary.
- `version` defaults to the pinned release `8.30.1` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gitleaks-cli:0": {
            "version": "8.30.1",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f gitleaks-cli -i debian:trixie --project-folder .
```
