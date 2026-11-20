# Google Cloud CLI (`gcloud`)

Installs the [Google Cloud CLI](https://cloud.google.com/sdk/docs) (`gcloud`, `gsutil`, and `bq`) from the official Google Cloud SDK release archives.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `594.0.0` | Google Cloud CLI version to install, for example `594.0.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli:0": {
            "version": "594.0.0"
        }
    }
}
```

## Notes

- Supports `linux/amd64` (`x86_64`), `linux/arm64` (Google's `arm` archive), and `linux/386` (`x86`).
- The SDK is installed in `/usr/local/lib/google-cloud-sdk`, with `gcloud`, `gsutil`, and `bq` linked into `/usr/local/bin`.
- The Linux builds are linked against glibc, so musl-based distributions such as Alpine Linux are not supported.
- The SDK directory is root-owned. Running `gcloud components install` as a non-root user requires write access to that directory, or install additional components at image build time.
- The CLI stores its configuration and credentials in `~/.config/gcloud`; this Feature does not persist that directory.
- `version` defaults to the pinned release `594.0.0` so builds are reproducible. Set `"version": "latest"` to install the current release at build time; that requires network access and a known checksum.

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the archive digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli:0": {
            "version": "594.0.0",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f gcloud-cli -i debian:trixie --project-folder .
```
