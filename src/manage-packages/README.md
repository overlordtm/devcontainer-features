# Manage System Packages

Installs and removes system packages with the image's default package manager. Supports `apt` (via `apt-get`) and `apk` (Alpine Linux).

The Feature refreshes the package metadata before making changes, removes the requested packages, installs the requested packages, and then cleans the local package cache to keep image layers small.

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `install` | string | `""` | Comma or space separated list of packages to install. |
| `remove` | string | `""` | Comma or space separated list of packages to remove before installing. |

Package names may include version or architecture qualifiers supported by the package manager, such as `pkg=1.2.3`.

## Usage

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/manage-packages:0": {
            "install": "curl, git, jq",
            "remove": "nano"
        }
    }
}
```

## Behavior

1. Detects the package manager: `apt-get` first, then `apk`. If neither is available, the build fails.
2. Runs `apt-get update` or `apk update`.
3. Removes packages from the `remove` list, if any.
4. Installs packages from the `install` list with `--no-install-recommends` on apt, if any.
5. Cleans the package cache (`apt-get clean` and removes `/var/lib/apt/lists`, or `apk cache clean` and removes `/var/cache/apk`).

Because apt package lists are removed at the end, later Dockerfile steps that use `apt-get install` must run `apt-get update` first. Dev Container Features that install packages already do this.

On Debian/Ubuntu, removal uses `apt-get remove`, which keeps configuration files. It does not purge packages or automatically remove unused dependencies. On Alpine, removal uses `apk del`.
