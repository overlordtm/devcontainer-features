# GitHub CLI Persistence

Persists [`gh`](https://github.com/cli/cli) authentication, configuration, extensions, and state across container rebuilds, so you do not have to run `gh auth login` again after every rebuild.

This is a **companion Feature**: it does not install the `gh` CLI. Use it alongside [`gh-cli`](../gh-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gh-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gh-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `${devcontainerId}-gh-cli-state` and mounts it at `/dc/gh`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/gh` | `hosts.yml` with accounts and tokens, and `config.yml` |
| `data/` | `~/.local/share/gh` | installed extensions and the `gh copilot` binary |
| `state/` | `~/.local/state/gh` | update check state and extension update metadata |

On first container creation, existing directories moved to `<path>.pre-persistence` at build time are migrated into the empty volume.

The cache (`~/.cache/gh`) is deliberately **not** persisted because it is regenerable.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default paths. If you override `GH_CONFIG_DIR`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, or `XDG_STATE_HOME`, `gh` will not use these symlinks.
- The volume is scoped to the dev container ID, so each project keeps its own authentication and extension state across rebuilds without sharing it with other containers on the Docker host. To wipe it, remove the volume with `docker volume rm <devcontainerId>-gh-cli-state`.
- The volume contains `hosts.yml`, which holds access tokens. Treat it as sensitive (`gh` writes it with mode `0600`).

## Testing

```bash
devcontainer features test -f gh-cli-persistence -i debian:trixie --project-folder .
```
