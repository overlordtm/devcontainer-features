# direnv

Installs [direnv](https://direnv.net/) from the official GitHub releases and configures shell hooks.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | direnv version to install. |
| `configureShells` | boolean | `true` | Add hooks to system-wide bash, zsh, and fish startup files. |
| `hash` | string | `auto` | SHA-256/SHA-512 checksum, `auto` to use the built-in checksum map, or `disabled` to skip verification. |

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

## Checksum verification

Downloads are checked against the built-in SHA-256 map for known versions. If `latest` resolves to a version that is not in the map, the build fails unless you provide the artifact digest explicitly or opt out. For example:

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/direnv:0": {
            "version": "2.38.2",
            "hash": "<sha256-or-sha512-digest>"
        }
    }
}
```

Set `"hash": "disabled"` to skip verification. Only do this if you have another way to trust the download.

## Testing

```bash
devcontainer features test -f direnv -i debian:trixie --project-folder .
```
