# age CLI

Installs the [age](https://age-encryption.org/) file encryption CLI from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `1.3.2` | age version to install, for example `1.3.2`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/age-cli:0": {
            "version": "1.3.2"
        }
    }
}
```

Both `age` and `age-keygen` are installed into `/usr/local/bin`.

## Notes

- Supports `linux/amd64`, `linux/arm64`, and `linux/arm`.
- `version` defaults to the pinned release `1.3.2` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.
- age stores keys wherever you place them; this Feature only installs the binaries. It does not mount, copy, or persist keys.

## Mounting age keys from the host

Feature options cannot create host bind mounts: mounts in `devcontainer-feature.json` are static and resolved before `install.sh` runs. Add key mounts to your own `devcontainer.json` instead. Use one mount per key file:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/age-cli:0": {}
    },
    "mounts": [
        "source=${localEnv:HOME}/.config/sops/age/personal_keys.txt,target=/home/vscode/.config/sops/age/personal_keys.txt,type=bind,readonly",
        "source=${localEnv:HOME}/.config/sops/age/work_keys.txt,target=/home/vscode/.config/sops/age/work_keys.txt,type=bind,readonly"
    ]
}
```

To expose the whole key directory at once:

```jsonc
{
    "mounts": [
        "source=${localEnv:HOME}/.config/sops/age,target=/home/vscode/.config/sops/age,type=bind,readonly"
    ]
}
```

Replace `/home/vscode` with the home directory of your `remoteUser` (for example `/root` or `/home/node`).

SOPS reads `~/.config/sops/age/keys.txt` by default. If you mount a key under a different name, point `SOPS_AGE_KEY_FILE` at it or pass the appropriate age key option:

```jsonc
{
    "remoteEnv": {
        "SOPS_AGE_KEY_FILE": "/home/vscode/.config/sops/age/personal_keys.txt"
    }
}
```

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/age-cli:0": {
            "version": "1.3.2",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f age-cli -i debian:trixie --project-folder .
```
