# OpenCode Persistence

Persists [OpenCode](https://opencode.ai/docs) config, authentication, and session data across container rebuilds.

This is a **companion Feature**: it does not install the `opencode` CLI. Use it alongside an installation Feature, for example:

```jsonc
{
    "features": {
        "ghcr.io/jsburckhardt/devcontainer-features/opencode:1": {},
        "ghcr.io/overlordtm/devcontainer-features/opencode-persistence:0": {}
    }
}
```

## What it does

Creates a Docker named volume named `opencode-state` and mounts it at `/dc/opencode`. The volume contains:

| Volume subdirectory | Symlinked from | Contents |
| --- | --- | --- |
| `config/` | `~/.config/opencode` | `opencode.json`, plugins, agents, themes |
| `data/` | `~/.local/share/opencode` | `auth.json`, SQLite database, sessions, logs |
| `state/` | `~/.local/state/opencode` | UI state, selected model, prompt history |

On first container creation, existing directories moved to `<path>.pre-persistence` at build time are migrated into the empty volume.

The cache (`~/.cache/opencode`) is deliberately **not** persisted because it is regenerable and can be large.

## Options

This Feature has no options.

## Notes

- The Feature assumes the default XDG paths. If you override `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, or `XDG_STATE_HOME`, OpenCode will not use these symlinks.
- The volume is shared by every container on the same Docker host that uses this Feature, so you authenticate once across projects.
- Compose-based dev containers may prefix the volume name with the Compose project name. Pin the name if you want true sharing:

  ```yaml
  volumes:
    opencode-state:
      name: opencode-state
  ```

- The volume contains credentials and session history. Treat it as sensitive.

## Testing

```bash
devcontainer features test -f opencode-persistence -i debian:trixie --project-folder .
```
