# GitLab CLI (`glab`)

Installs the official [GitLab CLI](https://gitlab.com/gitlab-org/cli) from GitLab releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `1.131.0` | `glab` version to install, for example `1.131.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/glab-cli:0": {
            "version": "1.131.0"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/armv6`, `linux/386`, `linux/ppc64le`, and `linux/s390x`.
- `glab` stores its configuration in `~/.config/glab-cli`; this Feature does not persist that directory. Pair it with [`glab-cli-persistence`](../glab-cli-persistence) to keep authentication, aliases, and managed binaries across container rebuilds.
- `version` defaults to the pinned release `1.131.0` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the tarball digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/glab-cli:0": {
            "version": "1.131.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f glab-cli -i debian:trixie --project-folder .
```
