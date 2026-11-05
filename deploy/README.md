# Hermes deployment

## What runs where

The [Dockerfile](../Dockerfile) extends the latest official Hermes image with
GitHub CLI, a Git credential helper, a pinned Nous Research Copilot provider,
and our [default configuration](../docker/config.yaml). All dependencies are
built into our image, not installed during deployment. Credentials never enter
the image build.

The manually triggered [workflow](../.github/workflows/deploy-hermes.yml):

1. Verifies read-only VPS API access using OVHcloud's official CLI container.
2. Uses Docker's official Actions to build/cache/publish to
   `ghcr.io/vgol/marusya-agent`, with GitHub Actions layer caching.
3. Configures verified SSH access using an existing SSH setup Action.
4. Ensures GitHub CLI is installed on the VPS using Ubuntu's package manager.
5. Uses native Docker Compose over an SSH Docker context to pull and start
   the **exact GHCR digest** built by that run.
6. Verifies container health, the CLI, authenticated GitHub project access and
   an actual Copilot response.

There is no Ansible, Terraform dependency, custom deployment script, image
transfer by SCP, host Hermes installation or public application port.

## Configure the VPS address

Store the VPS public IP as the repository **Actions variable** `VPS_HOST`,
not as a secret or a literal in tracked files. Authenticate GitHub CLI and
enter the address from the OVH dashboard when prompted:

```sh
gh auth login --hostname github.com --web
gh variable set VPS_HOST --repo vgol/marusya-agent
VPS_HOST=$(gh variable get VPS_HOST --repo vgol/marusya-agent)
```

The workflow reads `${{ vars.VPS_HOST }}`. For the local commands below, load
`VPS_HOST` with the last command again whenever you open a new terminal.

## 1. Complete initial OVHcloud access

Follow OVH's [Getting started with a VPS](https://docs.ovhcloud.com/en/guides/bare-metal-cloud/virtual-private-servers/starting-with-a-vps)
and [GitHub Actions deployment guide](https://docs.ovhcloud.com/en/guides/bare-metal-cloud/virtual-private-servers/deploy-website-github-actions).

For this existing VPS:

- Host: the `VPS_HOST` Actions variable, SSH port `22`.
- OVH service: `vps-9ce61658.vps.ovh.ca`.
- Expected OS/user: Ubuntu 24.04 amd64, `ubuntu`, not root.

First sign in using the delivery email's temporary password, change it when
prompted, and reconnect after OVH closes that first session. Install/test your
personal public SSH key before disabling password login. Use sudo for
administration; do not enable root SSH login.

Create a separate unencrypted deployment key on your computer:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/marusya-deploy -C github-actions-marusya
ssh-copy-id -i ~/.ssh/marusya-deploy.pub "ubuntu@$VPS_HOST"
```

Verify the host fingerprint through OVH's authenticated KVM console:

```sh
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

Then locally capture the host key and compare fingerprints:

```sh
ssh-keyscan -p 22 -t ed25519 "$VPS_HOST" > /tmp/marusya-known-hosts
ssh-keygen -lf /tmp/marusya-known-hosts
```

Only use that file after the fingerprint matches. `ssh-keyscan` alone does not
establish trust. The workflow never disables host-key checking.

Allow inbound SSH in both VPS and OVH firewalls. GitHub-hosted runners do not
have one fixed source IP. No Hermes application port needs to be opened.

## 2. Install Docker once on the VPS

Use OVH's [Docker Engine and Compose installation guide](https://docs.ovhcloud.com/en/guides/bare-metal-cloud/virtual-private-servers/install-docker-on-vps),
with the **Ubuntu** repository for this Ubuntu VPS. The guide's displayed
Debian repository URL must not be copied unchanged onto Ubuntu.

Docker must be installed, its systemd service enabled, and Compose installed.
Following OVH's guide, grant the deployment account Docker access and reconnect
so the new group membership takes effect. Verify with the deployment key:

```sh
ssh -i ~/.ssh/marusya-deploy "ubuntu@$VPS_HOST" 'docker info'
ssh -i ~/.ssh/marusya-deploy "ubuntu@$VPS_HOST" 'docker compose version'
```

Docker-group access is **root-equivalent**. Protect the deployment key and
repository/workflow administration accordingly; use a separate deployment
account if preferred, setting `VPS_USER` to that account. The workflow's
standard APT commands also require passwordless sudo to install host-side
GitHub CLI; verify `sudo -n true` with the deployment account.

OVH OS/application templates and cloud-init at installation time do not
retroactively add packages to an existing running VPS. Reinstalling can erase
data, so this workflow never rebuilds or reinstalls the server. Installing
Docker via the documented one-time setup avoids an extra provisioning system.

## 3. Set GitHub Secrets

After configuring the address variable above, create repository **Actions
secrets** using Settings, or:

```sh
gh secret set VPS_USER --repo vgol/marusya-agent --body 'ubuntu'
gh secret set VPS_PORT --repo vgol/marusya-agent --body '22'
gh secret set VPS_SSH_KEY --repo vgol/marusya-agent < ~/.ssh/marusya-deploy
gh secret set VPS_KNOWN_HOSTS --repo vgol/marusya-agent < /tmp/marusya-known-hosts
rm /tmp/marusya-known-hosts
```

The user and port default to `ubuntu` and `22`. Do not reuse your personal
private key as the deployment key.

### OVHcloud API credentials

Create credentials at <https://eu.api.ovh.com/createToken/> restricted to:

- `GET /vps/vps-9ce61658.vps.ovh.ca`
- `GET /vps/vps-9ce61658.vps.ovh.ca/*`

The account uses `ovh-eu`, irrespective of the VPS being in Canada. No order,
payment, rebuild, termination or write permission is needed. Each command
prompts securely:

```sh
gh secret set OVH_APPLICATION_KEY --repo vgol/marusya-agent
gh secret set OVH_APPLICATION_SECRET --repo vgol/marusya-agent
gh secret set OVH_CONSUMER_KEY --repo vgol/marusya-agent
```

These are three separate OVH credentials. They stay in the API-check job,
never in Hermes. OVH API authentication does not replace SSH OS access.
OVH's published VPS Actions guide uses SSH, not a VPS-specific OVH Action;
we use the official OVH CLI image for the read-only API check.

### Agent credentials

```sh
gh secret set COPILOT_GITHUB_TOKEN --repo vgol/marusya-agent
gh secret set HERMES_GITHUB_TOKEN --repo vgol/marusya-agent
```

- `COPILOT_GITHUB_TOKEN`: a fine-grained PAT with **Copilot Requests**
  permission and an active Copilot subscription, or a supported Copilot OAuth
  token (`gho_`/`ghu_`). Classic PATs and Actions' `GITHUB_TOKEN` are not
  Copilot credentials. Ensure your organization's policy permits usage.
- `HERMES_GITHUB_TOKEN`: a fine-grained PAT scoped only to this repository,
  with Metadata read and Contents read/write. Add Issues/Pull requests
  read/write only if needed. Do not grant workflow write or all-repository
  access unnecessarily.

The image includes Nous Research's
[Copilot Labs provider](https://hermes-agent.nousresearch.com/docs/plugins/github-copilot),
pinned to reviewed commit `346cfe972f72b6a966e84c1004cf8742554b193d`.
It is functional but upstream labels Labs plugins **unsupported**.
The image's default model is `gpt-6.1-sol`; change the tracked image configuration
if your subscription requires another model.

Compose sources credentials from GitHub Secrets and copies a root-owned,
read-only file into `/etc/hermes/.env` through the Docker API over SSH.
Hermes' supported managed configuration scope loads it. Tokens are not image
layers, command-line arguments, remote Git URLs or persistent Docker
environment metadata. The unprivileged agent can read but cannot modify the
credential file. This requires a recent Compose version supporting
environment-sourced secrets; the workflow uses the hosted runner's Compose.

**Runtime limit:** GitHub encrypts stored secrets and masks logs, but Hermes,
agent-executed code and VPS/Docker administrators can still read credentials
the agent needs. The file is not an encrypted-at-rest VPS secret store.
Avoid debug logging and never print rendered Compose configuration with
production credentials. Rotate secrets in GitHub and redeploy; forced
container recreation applies the new credential files.

GHCR push/pull authentication uses the short-lived workflow `GITHUB_TOKEN`.
It remains on the runner and is removed by Docker's login Action cleanup.
No registry PAT or stored registry credential on the VPS is needed. If an
existing GHCR package has independent permissions, grant this repository's
Actions access in the package settings.

## 4. Publish and deploy manually

Merge the issue-#7 branch so the workflow exists on the default branch.
GitHub requires that before exposing a manually dispatched workflow.
Run **Actions → Build and deploy Hermes → Run workflow**, or:

```sh
gh workflow run deploy-hermes.yml --repo vgol/marusya-agent
gh run list --repo vgol/marusya-agent --workflow deploy-hermes.yml --limit 5
gh run watch --repo vgol/marusya-agent <run-id> --exit-status
```

Runs are serialized. There are no push/PR/scheduled deployments. The final
check requires an exact `HERMES_DEPLOY_OK` model response and can consume one
Copilot request. Authentication or deployment failures fail the workflow.

## 5. Connect and operate

Use your personal SSH key:

```sh
ssh -t "ubuntu@$VPS_HOST" 'docker exec -it --user hermes hermes hermes'
ssh "ubuntu@$VPS_HOST" 'docker exec --user hermes hermes hermes --version'
ssh "ubuntu@$VPS_HOST" 'docker logs --tail 100 hermes'
```

The container is named `hermes`; the last `hermes` is the executable. Ask the
agent to clone `https://github.com/vgol/marusya-agent.git` into its workspace.
Its repository token and GitHub CLI credential helper provide authenticated
access without putting a token in the URL. The workflow verifies access
before reporting deployment success. Hermes Desktop is deferred.

GitHub CLI is available both inside Hermes and on the VPS host. For your own
host-side administration, SSH into the VPS and run `gh auth login --web`.
That host login is independent of the agent's repository-scoped token; the
workflow does not copy the agent token into the host user's GitHub CLI config.

State persists in the `marusya_data` Docker volume across redeployments and
reboots. Existing config is preserved; image defaults seed only fresh volumes.
The container uses `unless-stopped` restart policy and bounded logs. No Docker
socket or host home directory is mounted into Hermes.

Stop active CLI sessions before redeploying, and securely back up the data
volume while stopped before upgrades. Do not use `compose down --volumes`
unless intentionally deleting all agent data. There is no automatic database
rollback; review migration compatibility before deploying an older digest.

## Local checks

```sh
actionlint .github/workflows/deploy-hermes.yml
docker build --pull -t marusya-agent:test .
docker run --rm marusya-agent:test --version
```
