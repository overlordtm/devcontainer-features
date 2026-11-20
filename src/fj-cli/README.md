# Forgejo CLI (`fj`)

Installs [`fj`](https://codeberg.org/forgejo-contrib/forgejo-cli), a command-line client for Forgejo and Gitea, from the official releases.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `fj` version to install, for example `0.7.0`. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |
| `client_id` | string | `""` | OAuth client ID mapping for `fj`: either `<host> <uuid>` or the name of a file in the workspace `.devcontainer` directory. |

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

## OAuth client IDs

`fj auth login` only supports OAuth for a known list of instances. To add another instance, provide its OAuth client ID mapping through the `client_id` option. The following forms are accepted:

- An inline mapping made of a host or URL, one or more whitespace characters, and a UUID, for example `forge.example.com 00112233-4455-6677-8899-aabbccddeeff`. The value is written to `/etc/fj/client_ids` during the image build.
- A file name such as `fj-client_ids`. If the value does not look like an inline mapping, it is treated as the name of a file in the workspace `.devcontainer` directory. Because the workspace is not available while the image is built, the file is copied to `/etc/fj/client_ids` when the container is created.

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {
            "client_id": "forge.example.com 00112233-4455-6677-8899-aabbccddeeff"
        }
    }
}
```

Or, with a file named `.devcontainer/fj-client_ids`:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {
            "client_id": "fj-client_ids"
        }
    }
}
```

The file uses the same format as `/etc/fj/client_ids`: one `<host> <uuid>` mapping per line.

## Notes

- Official `fj` binaries are published for Linux `x86_64` and `aarch64` and require a glibc-based distribution with OpenSSL 3 (for example Debian 12+ or Ubuntu 22.04+).
- On musl distributions such as Alpine, or when the prebuilt binary cannot run, the Feature falls back to `cargo install forgejo-cli --locked` if Cargo is available. Otherwise it fails with an explanation.
- `fj` stores its configuration under the user's XDG config directory. This Feature does not persist it.

## Opening URLs

`fj` opens URLs through `xdg-open`/`gio` (the Rust `open` crate) and ignores `$BROWSER`. A container has no browser, so this Feature installs `/usr/local/bin/xdg-open` as a shim that hands the URL to the browser helper VS Code exposes through `$BROWSER`. Browser-opening commands such as `fj auth login` then use the host browser.

The shim is placed in `/usr/local/bin`, which takes precedence over a system `xdg-open` such as the one from `xdg-utils`.

VS Code only sets `$BROWSER` in attached terminals. When you run `fj` some other way, for example through `docker exec`, set `BROWSER` to a command that can open URLs first. Otherwise the shim exits with `BROWSER not set (VS Code sets it in attached terminals)`.

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
