# GitLab CLI Persistence

Persists [`glab`](https://gitlab.com/gitlab-org/cli) authentication, configuration, aliases, and managed binaries across container rebuilds, so you do not have to run `glab auth login` again after every rebuild.

This is a **companion Feature**: it does not install the `glab` CLI. Use it alongside [`glab-cli`](../glab-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/glab-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/glab-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `${localWorkspaceFolderBasename}-${devcontainerId}-glab-cli-state` and mounts it at `/dc/glab`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/glab-cli` | `config.yml` with hosts and tokens, `aliases.yml`, and the `bin/` directory for binaries managed by `glab` |

On first container creation, an existing `~/.config/glab-cli` directory moved to `~/.config/glab-cli.pre-persistence` at build time is migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default paths. If you override `GLAB_CONFIG_DIR` or `XDG_CONFIG_HOME`, `glab` will not use this symlink.
- If `glab` stores credentials in the operating system keyring instead of `config.yml` (keyring storage is used automatically when a keyring backend is available), those credentials are not part of the volume. In a typical container, no keyring backend is available and `glab` writes the token to `config.yml`.
- The volume name starts with the workspace folder name so it is easy to spot in `docker volume ls`, and includes the dev container ID to keep it unique. This means each project keeps its own authentication and aliases across rebuilds without sharing them with other containers on the Docker host, even when two projects have the same folder name. To wipe it, remove the volume with `docker volume rm <workspace-folder>-<devcontainerId>-glab-cli-state`.
- The volume contains `config.yml`, which can hold access tokens. Treat it as sensitive (`glab` writes it with mode `0600`).

## Testing

```bash
devcontainer features test -f glab-cli-persistence -i debian:trixie --project-folder .
```
