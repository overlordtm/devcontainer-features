# GitLab CLI (`glab`)

Installs the official [GitLab CLI](https://gitlab.com/gitlab-org/cli) from GitLab releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `glab` version to install, for example `1.131.0`. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/OWNER/devcontainer-features/glab-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/armv6`, `linux/386`, `linux/ppc64le`, and `linux/s390x`.
- `glab` stores its configuration in `~/.config/glab-cli`. This Feature does not persist that directory; add a mount if you need it to survive rebuilds.

## Testing

```bash
devcontainer features test -f glab-cli -i debian:trixie --project-folder .
```
