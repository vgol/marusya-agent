# Marusya Agent

Marusya Agent is a workspace for AI-assisted automation powered by
[Hermes Agent](https://github.com/NousResearch/hermes-agent). Its intended use
cases include:

- Coding and software development
- Finance and accounting
- Document and email processing

This repository holds the non-private code, infrastructure configuration and
development tooling for the project. Private documents, credentials and agent
session data should stay outside version control.

## Current scope

The repository provides a development container and a manually triggered
Hermes build/deployment workflow for an existing OVHcloud VPS. Nothing orders
or reinstalls servers.

## Deploy Hermes

The [deployment guide](deploy/README.md) covers initial OVHcloud SSH access,
GitHub Secrets and running **Build and deploy Hermes**. Docker's official
Actions build and cache our [derived image](Dockerfile), then publish it to
GHCR. Docker Compose connects over verified SSH and pulls the exact image
digest onto the Docker-enabled VPS. Hermes includes GitHub Copilot support and
authenticated access to this project; CLI access is over SSH only, without
public application ports.

## Getting started

Open the repository in GitHub Codespaces, or locally in Visual Studio Code
with Docker and the Dev Containers extension installed. Run
**Dev Containers: Rebuild and Reopen in Container** to build and enter the
development environment.

The environment is configured in
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) and uses
a Debian Bookworm base with:

- Zsh and Oh My Zsh
- Docker-in-Docker
- GitHub Copilot CLI and GitHub CLI
- Dev Container CLI
- TypeScript
- uv and uvx for Python tooling
- OVHcloud CLI

The [devcontainer Dockerfile](.devcontainer/Dockerfile) installs uv and uvx
from Astral's official image and the OVHcloud CLI from OVHcloud's official
image. Authenticate individual tools only when needed; do not commit
authentication tokens.

To build and enter the environment through the Dev Container CLI:

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

These commands require Docker and the Dev Container CLI on the host.

## Local files and secrets

The root [`.gitignore`](.gitignore) covers local environments, OVH configuration
and legacy infrastructure artifacts. Keep dependency lockfiles in version
control. Ignore rules are not a security boundary: review changes for secrets
before committing, and protect local credentials and state files.

## License

Licensed under the [Apache License 2.0](LICENSE).
