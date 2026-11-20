# TFLint CLI (`tflint`)

Installs the [TFLint](https://github.com/terraform-linters/tflint) Terraform linter CLI from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | TFLint version to install, for example `0.66.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/tflint-cli:0": {
            "version": "latest"
        }
    }
}
```

## Notes

- Supports `linux/amd64`, `linux/arm64`, `linux/arm`, and `linux/386`.
- `tflint` is installed as `/usr/local/bin/tflint`.
- `unzip` is installed if it is not already present.
- TFLint downloads rule sets (for example `tflint-ruleset-aws`) at runtime and caches them in `~/.tflint.d`; this Feature only installs the binary.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the archive digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/tflint-cli:0": {
            "version": "0.66.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f tflint-cli -i debian:trixie --project-folder .
```
