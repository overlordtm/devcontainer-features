# Dev Container Features

A collection of [Dev Container Features](https://containers.dev/implementors/features/) for AI coding agents and common CLI tools.

## Features

| Feature | Description |
| --- | --- |
| [`claude-code`](src/claude-code) | Installs the Claude Code CLI from official native releases. |
| [`claude-code-persistence`](src/claude-code-persistence) | Persists Claude Code account, settings, and session history across container rebuilds. |
| [`opencode-cli`](src/opencode-cli) | Installs the OpenCode 2 CLI. |
| [`opencode-persistence`](src/opencode-persistence) | Persists OpenCode config, authentication, and session data across container rebuilds. |
| [`direnv`](src/direnv) | Installs direnv and configures bash, zsh, and fish hooks. |
| [`go`](src/go) | Installs the Go programming language toolchain from official upstream releases. |
| [`shell-history`](src/shell-history) | Persists bash, zsh, and fish shell history across container rebuilds. |
| [`omz-plugins`](src/omz-plugins) | Adds, removes, or replaces Oh My Zsh plugins in the remote user's `.zshrc`. |
| [`glab-cli`](src/glab-cli) | Installs the official GitLab CLI (`glab`). |
| [`gh-cli`](src/gh-cli) | Installs the GitHub CLI (`gh`). |
| [`gh-cli-persistence`](src/gh-cli-persistence) | Persists `gh` authentication, configuration, extensions, and state across container rebuilds. |
| [`opentofu-cli`](src/opentofu-cli) | Installs the OpenTofu CLI (`tofu`). |
| [`sops-cli`](src/sops-cli) | Installs the SOPS secrets management CLI (`sops`). |
| [`age-cli`](src/age-cli) | Installs the age encryption CLI (`age` and `age-keygen`). |
| [`gcx-cli`](src/gcx-cli) | Installs the Grafana CLI (`gcx`). |
| [`gcx-cli-persistence`](src/gcx-cli-persistence) | Persists `gcx` configuration across container rebuilds. |
| [`gitleaks-cli`](src/gitleaks-cli) | Installs the Gitleaks secret scanning CLI (`gitleaks`). |
| [`gcloud-cli`](src/gcloud-cli) | Installs the Google Cloud CLI (`gcloud`, `gsutil`, and `bq`). |
| [`gcloud-cli-persistence`](src/gcloud-cli-persistence) | Persists `gcloud` configuration and credentials across container rebuilds. |
| [`aws-cli`](src/aws-cli) | Installs the AWS CLI v2 (`aws`). |
| [`aws-cli-persistence`](src/aws-cli-persistence) | Persists `aws` configuration, credentials, and SSO sessions across container rebuilds. |
| [`tflint-cli`](src/tflint-cli) | Installs the TFLint Terraform linter CLI (`tflint`). |
| [`uv-cli`](src/uv-cli) | Installs the uv Python package and project manager CLI (`uv` and `uvx`). |
| [`ruff-cli`](src/ruff-cli) | Installs the Ruff Python linter and formatter CLI (`ruff`). |
| [`fj-cli`](src/fj-cli) | Installs `fj`, the Forgejo/Gitea CLI. |
| [`fj-cli-persistence`](src/fj-cli-persistence) | Persists `fj` logins and configuration across container rebuilds. |
| [`manage-packages`](src/manage-packages) | Installs and removes system packages with apt or apk, then cleans the package cache. |

The `*-persistence` Features are companion Features: they do not install the tool itself. Pair them with an installation Feature or install the CLI through your image/Dockerfile.

## Download verification

Every CLI-installing Feature verifies downloaded artifacts against a built-in SHA-256 map of vetted versions. If you install a version that is not in the map, pass your own digest through the `hash` option, or set `"hash": "disabled"` to skip verification. A newly published upstream `latest` release is therefore rejected until the Feature's checksum map is updated (or you provide a digest). See the README of each Feature for details.

## Version defaults

Each CLI-installing Feature pins its `version` option to a specific, checksum-verified release, so builds are reproducible and do not depend on a release lookup at build time. Set `"version": "latest"` (or another version) explicitly if you want to resolve or install something else.

## Usage

Features are published under the `overlordtm/devcontainer-features` namespace.

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/claude-code:0": {},
        "ghcr.io/overlordtm/devcontainer-features/direnv:0": {},
        "ghcr.io/overlordtm/devcontainer-features/go:0": {},
        "ghcr.io/overlordtm/devcontainer-features/shell-history:0": {},
        "ghcr.io/overlordtm/devcontainer-features/omz-plugins:0": {
            "add": "zsh-autosuggestions, zsh-syntax-highlighting"
        },
        "ghcr.io/overlordtm/devcontainer-features/glab-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gh-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/opentofu-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/sops-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/age-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gitleaks-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/aws-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/tflint-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/opencode-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/manage-packages:0": {
            "install": "curl, git, jq"
        }
    }
}
```

### Persistence Features

```jsonc
{
    "features": {
        "ghcr.io/overlordtm/devcontainer-features/claude-code:0": {},
        "ghcr.io/overlordtm/devcontainer-features/claude-code-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/opencode-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/opencode-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/fj-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/fj-cli-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/gh-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gh-cli-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/gcx-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcx-cli-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/gcloud-cli-persistence:0": {},

        "ghcr.io/overlordtm/devcontainer-features/aws-cli:0": {},
        "ghcr.io/overlordtm/devcontainer-features/aws-cli-persistence:0": {}
    }
}
```

The persistence Features use Docker named volumes, so they also work in GitHub Codespaces where host bind mounts are not available. The volume names are intentionally shared between containers on the same Docker host, which means you sign in once and reuse the login across projects. See each Feature's README for the exact paths and volume names.

## Repository Structure

```text
src/<feature-id>/
    devcontainer-feature.json   # Feature metadata and options
    install.sh                  # Build-time installation entrypoint
    onCreate.sh                 # Optional container-creation lifecycle script
test/<feature-id>/
    test.sh                     # Autogenerated test
    scenarios.json              # Optional scenario definitions
    <scenario>.sh               # Scenario test
```

## Publishing

The [`.github/workflows/release.yaml`](.github/workflows/release.yaml) workflow packages every Feature under `src/` and publishes it to GitHub Container Registry (GHCR) as an OCI artifact, using the reference [`devcontainers/action`](https://github.com/devcontainers/action) implementation of the [Features distribution specification](https://containers.dev/implementors/features-distribution/).

Each Feature is published under the collection namespace `<owner>/<repo>`, for example:

```text
ghcr.io/overlordtm/devcontainer-features/direnv:0
ghcr.io/overlordtm/devcontainer-features/direnv:0.0.1
```

The action also publishes the `devcontainer-collection.json` metadata at `ghcr.io/overlordtm/devcontainer-features:latest`.

After the first publish, set each GHCR package to **public** in its package settings if you want others (or Codespaces) to consume it anonymously.

The workflow publishes on pushes to `main` that change `src/**`, or manually through `workflow_dispatch`. Feature versions are controlled by the `version` property in each `devcontainer-feature.json`; bump it before merging a change. Published versions are immutable.

You can validate packaging locally without publishing:

```bash
devcontainer features package -o ./output ./src
```

## Testing

Autogenerated tests run against all three Microsoft Dev Container base images: `mcr.microsoft.com/devcontainers/base:debian`, `mcr.microsoft.com/devcontainers/base:ubuntu`, and `mcr.microsoft.com/devcontainers/base:alpine`. These are the rolling "latest" tags for each distribution. Scenario tests may use other base images, for example `manage-packages` tests apt and apk on Debian and Alpine. The persistence scenarios cover both root and non-root remote users (the non-root scenario uses `common-utils` to create the user).

Install the Dev Container CLI, then run a Feature's tests:

```bash
npm install -g @devcontainers/cli

devcontainer features test -f direnv -i mcr.microsoft.com/devcontainers/base:debian --project-folder .
devcontainer features test -f claude-code-persistence -i mcr.microsoft.com/devcontainers/base:debian --project-folder .
```

Omit `--skip-scenarios` to run the scenarios in `scenarios.json` as well. The GitHub Actions test workflow runs both the autogenerated tests and the scenario tests.

## License

No license has been declared for this collection yet. Add a `LICENSE` file before distributing it publicly.
