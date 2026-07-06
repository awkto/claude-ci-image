# claude-code CI image

A minimal Docker image with [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
pre-installed, built for running Claude Code **non-interactively inside CI/CD
pipelines**.

- Base: `node:22-bookworm-slim`
- Runs as a non-root user (`node`, uid 1000)
- Multi-arch: `linux/amd64`, `linux/arm64`
- Published to Docker Hub: **[`awkto/claude-code`](https://hub.docker.com/r/awkto/claude-code)**

Maintained roughly monthly (or more often) by cutting a new semver tag, which
rebuilds against the latest Claude Code and base image.

## Quick start

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -v "$PWD":/workspace \
  awkto/claude-code \
  claude -p "Summarize what this repository does" --dangerously-skip-permissions
```

`claude -p` is print (headless) mode — it runs one prompt and exits, which is
what you want in CI. `--dangerously-skip-permissions` auto-approves tool use so
nothing blocks on an interactive prompt. This flag is why the image runs as a
non-root user: Claude Code refuses to use it under root.

## Authentication

Pass credentials via environment variables — never bake them into the image.

| Variable | Purpose |
| --- | --- |
| `ANTHROPIC_API_KEY` | Anthropic API key (most common for CI). |
| `CLAUDE_CODE_OAUTH_TOKEN` | Alternative: a Claude Code OAuth token (`claude setup-token`). |

In CI, store these as masked/secret variables and inject them at runtime, e.g.
`-e ANTHROPIC_API_KEY` (value taken from the runner's secret env).

## Files & directories you may want to mount

Claude Code reads configuration, skills, and memory from the home directory of
the user running it. In this image that user is **`node`**, home
**`/home/node`**. Your working directory should be mounted at **`/workspace`**.

| What | Path in container | Notes |
| --- | --- | --- |
| Your repo / project | `/workspace` | Mount your checkout here (the WORKDIR). |
| Project instructions | `/workspace/CLAUDE.md` | Comes with your repo; no separate mount needed. |
| Project config/skills | `/workspace/.claude/` | Per-project skills, commands, settings, agents. |
| Global config dir | `/home/node/.claude/` | Global `settings.json`, `CLAUDE.md`, and everything below. |
| Global instructions | `/home/node/.claude/CLAUDE.md` | Global memory / house rules. |
| Skills | `/home/node/.claude/skills/` | Reusable skills available to every project. |
| Slash commands | `/home/node/.claude/commands/` | Custom commands. |
| Subagents | `/home/node/.claude/agents/` | Custom agent definitions. |
| Memory / history | `/home/node/.claude/projects/` | Persisted project memory & session history. |
| Settings | `/home/node/.claude/settings.json` | Permissions, env, hooks. |
| MCP / auth config | `/home/node/.claude.json` | MCP servers and project trust. |

You can mount the whole `~/.claude` directory at once, or cherry-pick just the
pieces you need (skills + a settings file is a common minimal setup).

> **Ownership tip:** mounted files must be readable/writable by uid **1000**.
> If your host files are owned by a different uid, add `--user "$(id -u):$(id -g)"`
> to `docker run`, or `chown` the mounted paths.

### Mount examples

Bring your global skills and settings into a CI run:

```bash
docker run --rm \
  -e ANTHROPIC_API_KEY \
  -v "$PWD":/workspace \
  -v "$HOME/.claude/skills":/home/node/.claude/skills:ro \
  -v "$HOME/.claude/settings.json":/home/node/.claude/settings.json:ro \
  -v "$HOME/.claude/CLAUDE.md":/home/node/.claude/CLAUDE.md:ro \
  awkto/claude-code \
  claude -p "Run the release checklist" --dangerously-skip-permissions
```

See [`docker-compose.example.yml`](./docker-compose.example.yml) for the same
idea as a compose file.

## Using it in a pipeline

### GitHub Actions

```yaml
jobs:
  claude:
    runs-on: ubuntu-latest
    container:
      image: awkto/claude-code:latest
    steps:
      - uses: actions/checkout@v4
      - run: claude -p "Review the changes on this branch" --dangerously-skip-permissions
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### GitLab CI

```yaml
claude-review:
  image: awkto/claude-code:latest
  variables:
    ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY   # set as a masked CI/CD variable
  script:
    - claude -p "Review the changes in this MR" --dangerously-skip-permissions
```

## Tags

There are two independent families of tags:

**Image release tags** — versioned by *this repo* (the Dockerfile/config), built
from the latest Claude Code at build time. Cut via a semver git tag:

| Git tag | Docker tags |
| --- | --- |
| `v1.4.2` | `1.4.2`, `1.4`, `1`, `latest` |
| `v1.5.0-rc1` | `1.5.0-rc1` (no `latest`) |

**Claude Code version tags** — the image tag *is* the Claude Code version it
contains, e.g. `awkto/claude-code:2.1.201`. Reproducible and self-documenting.
Published on demand and weekly (tracking the newest Claude Code).

Which should you use?

- `:latest` — newest stable image, always current Claude Code. Good default.
- `:2.1.201` (a Claude Code version) — pin the exact Claude Code your pipeline runs.
- `:1.4.2` (an image release) — pin this repo's config/base as well.

## Releasing (maintainers)

Publishing happens **only on semver git tags**. To cut a release:

```bash
git tag v1.4.2
git push origin v1.4.2
```

The [`build-and-push`](./.github/workflows/build-push.yml) workflow builds the
multi-arch image and pushes all derived tags to Docker Hub. A monthly (or more
frequent) refresh is just a new tag — each build pulls the latest Claude Code
and base image.

### Publishing Claude-Code-version-pinned images

The [`publish-claude-version`](./.github/workflows/publish-claude-version.yml)
workflow builds an image pinned to a specific Claude Code version and tags it
with that version (e.g. `awkto/claude-code:2.1.201`). It does **not** touch
`latest`. It runs:

- **Weekly** (Mondays 06:00 UTC), tracking the newest Claude Code release.
- **On demand:** Actions → *publish-claude-version* → *Run workflow*, optionally
  entering an exact version. Or via CLI:

  ```bash
  gh workflow run publish-claude-version -f version=2.1.201
  ```

### Required repository secrets

| Secret | Value |
| --- | --- |
| `DOCKER_USERNAME` | Docker Hub username (`awkto`). |
| `DOCKER_PASSWORD` | Docker Hub access token (create at hub.docker.com → Account → Security). |

## Building locally

```bash
# Latest Claude Code
docker build -t claude-code .

# Pin a specific Claude Code version
docker build --build-arg CLAUDE_CODE_VERSION=1.4.2 -t claude-code:1.4.2 .
```

## License

[MIT](./LICENSE) — free and open source.
