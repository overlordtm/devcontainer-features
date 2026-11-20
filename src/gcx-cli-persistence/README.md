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

Creates a Docker named volume named `gcx-cli-state` and mounts it at `/dc/gcx`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/gcx` | `config.yaml` with stacks, contexts, and credentials |

On first container creation, an existing `~/.config/gcx` directory moved to `~/.config/gcx.pre-persistence` at build time is migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature persists only gcx's user configuration (`~/.config/gcx`). System and repository-level configuration files that gcx layers on top are not persisted.
- The volume is shared by every container on the same Docker host that uses this Feature, so you configure gcx once across projects.
- Compose-based dev containers may prefix the volume name with the Compose project name. Pin the name if you want true sharing:

  ```yaml
  volumes:
    gcx-cli-state:
      name: gcx-cli-state
  ```

- The volume may contain Grafana credentials and tokens. Treat it as sensitive.

## Testing

```bash
devcontainer features test -f gcx-cli-persistence -i debian:trixie --project-folder .
```
