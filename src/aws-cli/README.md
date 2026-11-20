# AWS CLI (`aws`)

Installs the [AWS CLI v2](https://aws.amazon.com/cli/) from the official AWS release bundles.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `2.42.0` | AWS CLI v2 version to install, for example `2.42.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/aws-cli:0": {
            "version": "2.42.0"
        }
    }
}
```

## Notes

- Supports `linux/amd64` (`x86_64`) and `linux/arm64` (`aarch64`).
- The AWS CLI is installed in `/usr/local/aws-cli`, with `aws` and `aws_completer` linked into `/usr/local/bin`.
- The Linux bundles are linked against glibc, so musl-based distributions such as Alpine Linux are not supported.
- The CLI stores its configuration and credentials in `~/.aws`; this Feature does not persist that directory.
- `version` defaults to the pinned release `2.42.0` so builds are reproducible. Set `"version": "latest"` to resolve the newest release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the bundle digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/aws-cli:0": {
            "version": "2.42.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f aws-cli -i debian:trixie --project-folder .
```
