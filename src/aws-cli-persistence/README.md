# AWS CLI Persistence

Persists [`aws`](https://aws.amazon.com/cli/) configuration, credentials, and SSO sessions across container rebuilds, so you do not have to run `aws configure` or `aws sso login` again after every rebuild.

This is a **companion Feature**: it does not install the `aws` CLI. Use it alongside [`aws-cli`](../aws-cli):

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/aws-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/aws-cli-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `${localWorkspaceFolderBasename}-${devcontainerId}-aws-cli-state` and mounts it at `/dc/aws`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.aws` | `config`, `credentials`, SSO token caches, CLI cache data, and models |

On first container creation, an existing `~/.aws` directory moved to `~/.aws.pre-persistence` at build time is migrated into the empty volume.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default `~/.aws` path. If you override `AWS_CONFIG_FILE`, `AWS_SHARED_CREDENTIALS_FILE`, or the CLI cache location, those paths are not persisted.
- The volume name starts with the workspace folder name so it is easy to spot in `docker volume ls`, and includes the dev container ID to keep it unique. This means each project keeps its own credentials and SSO sessions across rebuilds without sharing them with other containers on the Docker host, even when two projects have the same folder name. To wipe it, remove the volume with `docker volume rm <workspace-folder>-<devcontainerId>-aws-cli-state`.
- The volume contains `~/.aws/credentials` and SSO token caches, which hold secrets. Treat it as sensitive.

## Testing

```bash
devcontainer features test -f aws-cli-persistence -i debian:trixie --project-folder .
```
