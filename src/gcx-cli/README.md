# Grafana CLI (`gcx`)

Installs the [Grafana CLI](https://github.com/grafana/gcx) (`gcx`) from official GitHub releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `1.8.0` | gcx version to install, for example `1.8.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |
| `keychain` | boolean | `false` | Allow gcx to use the OS keychain. When `false`, `GCX_KEYCHAIN=off` is exported. |
| `telemetry` | boolean | `false` | Allow gcx to send telemetry. When `false`, `GCX_TELEMETRY=disabled` is exported. |

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {
            "version": "1.8.0"
        }
    }
}
```

## Notes

- Supports `linux/amd64` and `linux/arm64`.
- `gcx` is installed as `/usr/local/bin/gcx`.
- With the default `keychain: false` and `telemetry: false`, the Feature writes `GCX_KEYCHAIN=off` and `GCX_TELEMETRY=disabled` to `/etc/profile.d/gcx.sh` and `/etc/environment`. Shells and processes that are already running (for example the VS Code server) need to be restarted to pick up the change. Set either option to `true` to leave gcx's own default behavior in place.
- `version` defaults to the pinned release `1.8.0` so builds are reproducible. With `version: "latest"`, the release tag is resolved from the GitHub release page redirect rather than the REST API, which is rate limited for anonymous clients on shared CI runners. If the lookup still fails, pin `version` to a specific release.
- gcx stores its configuration in `~/.config/gcx`; this Feature does not persist that directory. Pair it with [`gcx-cli-persistence`](../gcx-cli-persistence) to keep the configuration across container rebuilds.

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
