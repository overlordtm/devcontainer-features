# Forgejo CLI (`fj`)

Installs [`fj`](https://codeberg.org/forgejo-contrib/forgejo-cli), a command-line client for Forgejo and Gitea, from the official releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `fj` version to install, for example `0.7.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Official `fj` binaries are published for Linux `x86_64` and `aarch64` and require a glibc-based distribution with OpenSSL 3 (for example Debian 12+ or Ubuntu 22.04+).
- On musl distributions such as Alpine, or when the prebuilt binary cannot run, the Feature falls back to `cargo install forgejo-cli --locked` if Cargo is available. Otherwise it fails with an explanation.
- `fj` stores its configuration under the user's XDG config directory. This Feature does not persist it.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {
            "version": "0.7.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

The `cargo install` fallback used on musl images is not covered by this checksum map; Cargo verifies crate registry metadata instead.

## Testing

```bash
devcontainer features test -f fj-cli -i debian:trixie --project-folder .
```
