# syntax=docker/dockerfile:1
FROM scratch AS copilot
ADD https://github.com/NousResearch/hermes-labs-plugins.git#346cfe972f72b6a966e84c1004cf8742554b193d /plugins

FROM docker.io/nousresearch/hermes-agent:latest

USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends gh \
    && git config --system credential.https://github.com.helper '!/usr/bin/gh auth git-credential' \
    && install -d -m 0755 /etc/hermes

COPY --from=copilot /plugins/github-copilot /opt/hermes/plugins/model-providers/github-copilot
COPY docker/config.yaml /opt/hermes/cli-config.yaml.example
RUN /command/s6-setuidgid hermes /opt/hermes/.venv/bin/python -c \
    "from providers import get_provider_profile; assert get_provider_profile('copilot') is not None"

ENV HOME=/opt/data HERMES_UID=10000 HERMES_GID=10000
WORKDIR /opt/data
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=12 \
    CMD /command/s6-setuidgid hermes test -r /etc/hermes/.env
CMD ["sleep", "infinity"]
