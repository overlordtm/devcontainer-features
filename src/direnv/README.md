# direnv

Installs [direnv](https://direnv.net/) from the official GitHub releases and configures shell hooks.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | direnv version to install. |
| `configureShells` | boolean | `true` | Add hooks to system-wide bash, zsh, and fish startup files. |

Set `configureShells` to `false` if you manage direnv hooks yourself.

## Shell integration

- `/etc/profile.d/direnv.sh` for login shells (bash and zsh).
- `/etc/bash.bashrc` and `/etc/bashrc` when present for interactive bash.
- `/etc/zsh/zshrc` and `/etc/zshrc` when zsh is installed.
- `/etc/fish/conf.d/direnv.fish` for fish.

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/direnv:0": {
            "version": "latest"
        }
    }
}
```

## Testing

```bash
devcontainer features test -f direnv -i debian:trixie --project-folder .
```
