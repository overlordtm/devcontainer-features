# Grafana CLI Persistence

Persists [`gcx`](https://github.com/grafana/gcx) configuration across container rebuilds, so stacks and contexts survive a rebuild.

This is a **companion Feature**: it does not install the `gcx` CLI. Use it alongside [`gcx-cli`](../gcx-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `${devcontainerId}-gcx-cli-state` and mounts it at `/dc/gcx`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/gcx` | `config.yaml` with stacks, contexts, and credentials |

On first container creation, an existing `~/.config/gcx` directory moved to `~/.config/gcx.pre-persistence` at build time is migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature persists only gcx's user configuration (`~/.config/gcx`). System and repository-level configuration files that gcx layers on top are not persisted.
- The volume is scoped to the dev container ID, so each project keeps its own gcx configuration across rebuilds without sharing it with other containers on the Docker host. To wipe it, remove the volume with `docker volume rm <devcontainerId>-gcx-cli-state`.
- The volume may contain Grafana credentials and tokens. Treat it as sensitive.

## Testing

```bash
devcontainer features test -f gcx-cli-persistence -i debian:trixie --project-folder .
```
