# Claude Code Persistence

Persists [Claude Code](https://code.claude.com/docs) account, settings, plugins, and session history across container rebuilds.

This is a **companion Feature**: it does not install the `claude` CLI. Use it alongside an installation Feature, for example:

```jsonc
{
    "features": {
        "ghcr.io/anthropics/devcontainer-features/claude-code:1": {},
        "ghcr.io/overlordtm/devcontainer-features/claude-code-persistence:0": {}
    }
}
```

## What it does

- Creates a Docker named volume named `claude-code-config` and mounts it at `/dc/claude`.
- Sets `CLAUDE_CONFIG_DIR=/dc/claude` through Feature `containerEnv` and `/etc/profile.d/00-claude-code-persistence.sh`, so Claude Code stores `.claude.json`, settings, history, and plugins on the volume.
- Symlinks `~/.claude` to `/dc/claude` for tools that ignore `CLAUDE_CONFIG_DIR`.
- On first container creation, migrates an existing `~/.claude` directory (moved to `~/.claude.pre-persistence` at build time) and `~/.claude.json` into the volume.

## Options

This Feature has no options.

## Notes

- The volume is shared by every container on the same Docker host that uses this Feature. That is deliberate: sign in once and use the same account and history across projects. Use separate Docker hosts (or remove the Feature) if you need isolation.
- Compose-based dev containers may prefix the volume name with the Compose project name. If you want true sharing, pin the volume name in `compose.yaml`:

  ```yaml
  volumes:
    claude-code-config:
      name: claude-code-config
  ```

- The volume contains credentials and conversation history. Treat it as sensitive, and only use it with projects you trust.

## Testing

```bash
devcontainer features test -f claude-code-persistence -i debian:trixie --project-folder .
```
