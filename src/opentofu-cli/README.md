# OpenTofu CLI (`tofu`)

Installs the [OpenTofu](https://opentofu.org/) CLI (`tofu`) from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | OpenTofu version to install, for example `1.13.9`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/opentofu-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/arm`, and `linux/386`.
- `tofu` is installed as `/usr/local/bin/tofu`.
- OpenTofu stores CLI configuration and plugin caches in `~/.tofu.d` and `~/.terraform.d`; this Feature does not persist those directories.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/opentofu-cli:0": {
            "version": "1.13.9",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f opentofu-cli -i debian:trixie --project-folder .
```
