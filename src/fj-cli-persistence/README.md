# Forgejo CLI Persistence

Persists [`fj`](https://codeberg.org/forgejo-contrib/forgejo-cli) logins and configuration across container rebuilds, so you do not have to run `fj auth login` again after every rebuild.

This is a **companion Feature**: it does not install the `fj` CLI. Use it alongside [`fj-cli`](../fj-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/fj-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `fj-cli-state` and mounts it at `/dc/fj`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `data/` | `~/.local/share/forgejo-cli` | `keys.json` with host logins, aliases, and default SSH hosts |
| `config/` | `~/.config/forgejo-cli` | optional per-user `client_ids` file |

On first container creation, existing directories moved to `<path>.pre-persistence` at build time are migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default XDG paths. If you override `XDG_DATA_HOME` or `XDG_CONFIG_HOME`, `fj` will not use these symlinks.
- The volume is shared by every container on the same Docker host that uses this Feature, so you log in once across projects. If you prefer a volume per project, mount one yourself instead of using this Feature, for example:

  ```jsonc
  "mounts": [
      "source=fj-cli-${devcontainerId},target=/dc/fj,type=volume"
  ]
  ```

  Do not combine that with this Feature: the Feature creates symlinks into `/dc/fj`, so the mount should target `/dc/fj`, not `~/.local/share/forgejo-cli`.

- Compose-based dev containers may prefix the volume name with the Compose project name. Pin the name if you want true sharing:

  ```yaml
  volumes:
    fj-cli-state:
      name: fj-cli-state
  ```

- The volume contains `keys.json`, which holds access and refresh tokens. Treat it as sensitive (`fj` writes it with mode `0600`).

## Testing

```bash
devcontainer features test -f fj-cli-persistence -i debian:trixie --project-folder .
```
