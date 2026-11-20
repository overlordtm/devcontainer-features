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

Creates a Docker named volume named `${devcontainerId}-fj-cli-state` and mounts it at `/dc/fj`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `data/` | `~/.local/share/forgejo-cli` | `keys.json` with host logins, aliases, and default SSH hosts |
| `config/` | `~/.config/forgejo-cli` | optional per-user `client_ids` file |

On first container creation, existing directories moved to `<path>.pre-persistence` at build time are migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default XDG paths. If you override `XDG_DATA_HOME` or `XDG_CONFIG_HOME`, `fj` will not use these symlinks.
- The volume is scoped to the dev container ID, so each project keeps its own logins across rebuilds without sharing them with other containers on the Docker host. To wipe it, remove the volume with `docker volume rm <devcontainerId>-fj-cli-state`.
- The volume contains `keys.json`, which holds access and refresh tokens. Treat it as sensitive (`fj` writes it with mode `0600`).

## Testing

```bash
devcontainer features test -f fj-cli-persistence -i debian:trixie --project-folder .
```
