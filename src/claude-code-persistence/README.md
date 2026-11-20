# Claude Code Persistence

Persists [Claude Code](https://code.claude.com/docs) account, settings, plugins, and session history across container rebuilds.

This is a **companion Feature**: it does not install the `claude` CLI. Use it alongside an installation Feature, for example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/claude-code:0": {},
        "ghcr.io/overlordtm/devcontainer-features/claude-code-persistence:0": {}
    }
}
```

## What it does

- Creates a Docker named volume named `${devcontainerId}-claude-code-config` and mounts it at `/dc/claude`.
- Sets `CLAUDE_CONFIG_DIR=/dc/claude` through Feature `containerEnv` and `/etc/profile.d/00-claude-code-persistence.sh`, so Claude Code stores `.claude.json`, settings, history, and plugins on the volume.
- Symlinks `~/.claude` to `/dc/claude` for tools that ignore `CLAUDE_CONFIG_DIR`.
- On first container creation, migrates an existing `~/.claude` directory (moved to `~/.claude.pre-persistence` at build time) and `~/.claude.json` into the volume.

## Options

This Feature has no options.

## Notes

- The volume is scoped to the dev container ID, so each project keeps its own account, settings, and session history across rebuilds without sharing them with other containers on the Docker host. To wipe it, remove the volume with `docker volume rm <devcontainerId>-claude-code-config`.
- The volume contains credentials and conversation history. Treat it as sensitive, and only use it with projects you trust.

## Testing

```bash
devcontainer features test -f claude-code-persistence -i debian:trixie --project-folder .
```
