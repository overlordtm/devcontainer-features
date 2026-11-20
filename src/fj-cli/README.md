# Forgejo CLI (`fj`)

Installs [`fj`](https://codeberg.org/forgejo-contrib/forgejo-cli), a command-line client for Forgejo and Gitea, from the official releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `fj` version to install, for example `0.7.0`. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/OWNER/devcontainer-features/fj-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Official `fj` binaries are published for Linux `x86_64` and `aarch64` and require a glibc-based distribution with OpenSSL 3 (for example Debian 12+ or Ubuntu 22.04+).
- On musl distributions such as Alpine, or when the prebuilt binary cannot run, the Feature falls back to `cargo install forgejo-cli --locked` if Cargo is available. Otherwise it fails with an explanation.
- `fj` stores its configuration under the user's XDG config directory. This Feature does not persist it.

## Testing

```bash
devcontainer features test -f fj-cli -i debian:trixie --project-folder .
```
