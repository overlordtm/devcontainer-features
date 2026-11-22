# Google Cloud CLI Persistence

Persists [`gcloud`](https://cloud.google.com/sdk/docs) configuration, credentials, and active configurations across container rebuilds, so you do not have to run `gcloud auth login` again after every rebuild.

This is a **companion Feature**: it does not install the `gcloud` CLI. Use it alongside [`gcloud-cli`](../gcloud-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `${localWorkspaceFolderBasename}-${devcontainerId}-gcloud-cli-state` and mounts it at `/dc/gcloud`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/gcloud` | configurations, `active_config`, `credentials.db`, `access_tokens.db`, application default credentials, and logs |

On first container creation, an existing `~/.config/gcloud` directory moved to `~/.config/gcloud.pre-persistence` at build time is migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default `~/.config/gcloud` path. If you override `CLOUDSDK_CONFIG` or `XDG_CONFIG_HOME`, `gcloud` will not use this symlink.
- `~/.gsutil` (gsutil transfer state and caches) is deliberately **not** persisted because it is regenerable.
- The volume name starts with the workspace folder name so it is easy to spot in `docker volume ls`, and includes the dev container ID to keep it unique. This means each project keeps its own credentials and configurations across rebuilds without sharing them with other containers on the Docker host, even when two projects have the same folder name. To wipe it, remove the volume with `docker volume rm <workspace-folder>-<devcontainerId>-gcloud-cli-state`.
- The volume contains OAuth credentials and access tokens. Treat it as sensitive.

## Testing

```bash
devcontainer features test -f gcloud-cli-persistence -i debian:trixie --project-folder .
```
