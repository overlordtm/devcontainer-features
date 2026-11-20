# Grafana CLI (`gcx`)

Installs the [Grafana CLI](https://github.com/grafana/gcx) (`gcx`) from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | gcx version to install, for example `1.8.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Supports `linux/amd64` and `linux/arm64`.
- `gcx` is installed as `/usr/local/bin/gcx`.
- gcx stores its configuration in `~/.config/gcx`; this Feature does not persist that directory.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {
            "version": "1.8.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f gcx-cli -i debian:trixie --project-folder .
```
