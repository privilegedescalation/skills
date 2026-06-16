---
name: gh-identity-guard
description: >
  Per-agent GH_CONFIG_DIR isolation and bot-identity assertion for GitHub
  operations. Prevents stale GH_CONFIG_DIR from causing agents to post under
  the wrong bot identity (see PRI-1791).
---

# gh-identity-guard

Security guard for all GitHub (`gh` CLI) operations. Prevents cross-agent token
contamination from a shared `$HOME/.env` and enforces per-agent identity
assertion before any official GitHub action (review, comment, push).

## Why This Skill Exists

`$HOME` (`/paperclip`) is shared across all agent workspaces. A sourced
`~/.env` from a prior or concurrent agent session can leave `GH_CONFIG_DIR`
pointing at a different agent's workspace directory. If the `gh` CLI inherits
that stale value it authenticates as the wrong bot and posts GitHub reviews /
comments under that bot's identity — corrupting the branch-protection audit
trail.

Root cause documented in [PRI-1791](/PRI/issues/PRI-1791).

## Rules

### Rule 1 — Re-derive on every invocation

At the start of any heartbeat, before calling `gh`, always re-derive
`GH_CONFIG_DIR` directly from `AGENT_HOME`:

```bash
export GH_CONFIG_DIR="$AGENT_HOME/.github"
mkdir -p "$GH_CONFIG_DIR"
```

Never trust an inherited `GH_CONFIG_DIR`. A value that does not start with
`$AGENT_HOME/` is stale from another agent and MUST be overwritten.

### Rule 2 — Pin GH_CONFIG_DIR on every `gh` call

Every `gh` invocation must carry `GH_CONFIG_DIR` explicitly in the environment,
not rely on a shell-level export that may have been overwritten by another agent:

```bash
GH_CONFIG_DIR="$AGENT_HOME/.github" gh <subcommand> [args...]
```

This applies to: `gh auth login`, `gh pr review`, `gh pr comment`, `gh api`,
`gh pr create`, `gh pr merge`, `git push` (when using gh-managed credentials).

### Rule 3 — Assert identity before any official GitHub action

Before submitting a PR review, posting a PR comment, or pushing to a protected
branch, verify the authenticated identity matches the expected bot for this
agent:

```bash
# Assert identity — abort on mismatch
bash skills/gh-identity-guard/scripts/assert-identity.sh "${EXPECTED_GH_LOGIN}"
```

Where `EXPECTED_GH_LOGIN` is the bot username for this agent (e.g.
`hugh-hackman-pe[bot]`). The script exits non-zero and prints a clear error if
the active account does not match.

If `EXPECTED_GH_LOGIN` is unknown, at minimum run:

```bash
GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1
```

and verify the `Active account:` line before proceeding.

### Rule 4 — Never source `~/.env` to load `GH_CONFIG_DIR`

`~/.env` (`/paperclip/.env`) accumulates `export GH_CONFIG_DIR=…` lines from
every agent that has ever run on this host. Sourcing it without sanitisation
loads the most recently appended value, which may belong to any other agent.

Instead source `$AGENT_HOME/.env` (the per-agent dotfile written by
`agent-setup`):

```bash
# Correct
[[ -f "$AGENT_HOME/.env" ]] && source "$AGENT_HOME/.env"
# Then re-derive to be safe
export GH_CONFIG_DIR="$AGENT_HOME/.github"
```

## Usage in Practice

### At heartbeat start (after agent-setup)

```bash
# 1. agent-setup sets GH_CONFIG_DIR=$AGENT_HOME/.github — but source the
#    per-agent file, not the global ~/.env, and then re-assert to be safe.
[[ -f "$AGENT_HOME/.env" ]] && source "$AGENT_HOME/.env"
export GH_CONFIG_DIR="$AGENT_HOME/.github"
mkdir -p "$GH_CONFIG_DIR"
```

### After github-app-token to confirm correct identity

```bash
# 2. After generating the token, confirm the active account is correct.
GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 | grep -E "Active account: true|Logged in"
```

### Before every PR review or comment

```bash
# 3. Assert identity before submitting the review.
bash skills/gh-identity-guard/scripts/assert-identity.sh "hugh-hackman-pe[bot]"
GH_CONFIG_DIR="$AGENT_HOME/.github" gh pr review <PR_NUMBER> --approve --body "..."
```

## Cross-Contamination Self-Test

To verify two agents running in overlapping shells cannot cross-contaminate:

```bash
# Simulate agent A setting a stale GH_CONFIG_DIR
export GH_CONFIG_DIR="/paperclip/instances/default/workspaces/AGENT-A/.github"

# Now run the guard — it must override the stale value
export GH_CONFIG_DIR="$AGENT_HOME/.github"

# Confirm GH_CONFIG_DIR now points to our AGENT_HOME
[[ "$GH_CONFIG_DIR" == "$AGENT_HOME/.github" ]] || { echo "FAIL: GH_CONFIG_DIR is $GH_CONFIG_DIR"; exit 1; }

# Confirm gh auth uses our config dir
GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 | grep -q "Active account: true" || echo "Not authenticated yet"
echo "PASS: GH_CONFIG_DIR is correctly isolated to $AGENT_HOME"
```

## Upstream fix tracking

The root fix in `agent-setup` and `github-app-token` scripts (from
`farhoodlabs/skills`) needs to be upstreamed. Until those changes land and are
deployed, this skill provides the agent-level defence.

Required upstream changes (tracked in [PRI-1791](/PRI/issues/PRI-1791)):
- `agent-setup/scripts/setup.sh`: validate `GH_CONFIG_DIR` is inside `AGENT_HOME`; write to `$AGENT_HOME/.env`, not `~/.env`
- `github-app-token/scripts/generate-token.sh`: validate `GH_CONFIG_DIR` is inside `AGENT_HOME`; pass `GH_CONFIG_DIR` explicitly on the `gh auth login` invocation
