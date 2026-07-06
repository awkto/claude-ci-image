# syntax=docker/dockerfile:1

# Base image with Claude Code pre-installed, intended for running Claude Code
# non-interactively inside CI/CD pipelines.

ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-bookworm-slim

# Version of @anthropic-ai/claude-code to install. Defaults to the latest
# published release; pin it for reproducible builds:
#   docker build --build-arg CLAUDE_CODE_VERSION=1.2.3 .
ARG CLAUDE_CODE_VERSION=latest

# Tools Claude Code and typical CI jobs rely on. Claude Code bundles its own
# ripgrep, but installing the system one is handy for user scripts.
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      ca-certificates \
      curl \
      openssh-client \
      less \
      jq \
      ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code globally.
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
    && npm cache clean --force

# CI-friendly defaults: no self-updates, no interactive/telemetry traffic.
ENV DISABLE_AUTOUPDATER=1 \
    DISABLE_TELEMETRY=1 \
    DISABLE_ERROR_REPORTING=1 \
    DISABLE_BUG_COMMAND=1 \
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    CI=true

# Run as a non-root user. This is required for the common CI invocation
# `claude --dangerously-skip-permissions`, which Claude Code refuses to run
# under root/sudo. The `node` user (uid 1000) already exists in the base image.
RUN mkdir -p /workspace && chown node:node /workspace
USER node
WORKDIR /workspace

# Claude Code reads config/skills/memory from the user's home directory.
# Pre-create the config dir so bind-mounts land with correct ownership.
RUN mkdir -p /home/node/.claude

LABEL org.opencontainers.image.title="claude-code" \
      org.opencontainers.image.description="Base image with Claude Code pre-installed for non-interactive CI/CD use" \
      org.opencontainers.image.source="https://github.com/awkto/claude-ci-image" \
      org.opencontainers.image.licenses="MIT"

# Surface the installed version in the build logs.
RUN claude --version

CMD ["bash"]
