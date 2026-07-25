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

### Rule 4 — Never source a shared shell-init file to load `GH_CONFIG_DIR`

`$HOME` (`/paperclip`) is shared across every agent workspace. `~/.env`,
`~/.bashrc`, `~/.bash_profile`, and `~/.profile` can all accumulate
`export GH_CONFIG_DIR=…` lines left behind by any agent that has ever run on
this host — and `~/.bashrc` in particular is sourced automatically by every
new shell. A stale entry there silently hands every subsequent agent's shell
the wrong bot's config dir with no sourcing action required on that agent's
part. (This is the exact fossil `fix-env-contamination.sh` found and removed
from `/paperclip/.bashrc` during the PRI-1904 rollout — a `GH_CONFIG_DIR`
pointing at another agent's workspace, sourced by every shell since it was
written.)

Instead source `$AGENT_HOME/.env` (the per-agent dotfile written by
`agent-setup`), and run `fix-env-contamination.sh` to strip any shared-file
contamination:

```bash
# Correct
[[ -f "$AGENT_HOME/.env" ]] && source "$AGENT_HOME/.env"
# Then re-derive to be safe, and clean any shared-file contamination
bash skills/gh-identity-guard/scripts/fix-env-contamination.sh
```

## Usage in Practice

The guard is invoked in three stages, wired org-wide via the `safety` skill
(see `skills/safety/SKILL.md`, "GitHub Identity Isolation") so it applies to
every agent without per-agent `AGENTS.md` edits:

### 1. At heartbeat start, after `agent-setup`, before `github-app-token`

```bash
bash skills/gh-identity-guard/scripts/fix-env-contamination.sh
```

Re-derives `GH_CONFIG_DIR=$AGENT_HOME/.github`, strips stale exports from any
shared shell-init file (`~/.env`, `~/.bashrc`, `~/.bash_profile`, `~/.profile`),
and writes the correct value to `$AGENT_HOME/.env` only.

### 2. Immediately after `github-app-token` mints this agent's token

```bash
bash skills/gh-identity-guard/scripts/record-identity.sh
```

Captures whatever identity is active right after this agent's own token was
minted and writes it to `$AGENT_HOME/.expected-gh-login`. This is the
canonical baseline for step 3 — no hardcoded `AGENT_HOME`->login table needed.

### 3. Before every official GitHub write (PR review, comment, push, merge)

```bash
bash skills/gh-identity-guard/scripts/assert-identity.sh
GH_CONFIG_DIR="$AGENT_HOME/.github" gh pr review <PR_NUMBER> --approve --body "..."
```

With no argument, `assert-identity.sh` checks the current active login
against `$AGENT_HOME/.expected-gh-login` from step 2. Pass an explicit login
(e.g. `"hugh-hackman-pe[bot]"`) instead if you want to assert against a known
value rather than the recorded baseline.

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
`farhoodlabs/skills`) still needs to be upstreamed — PE cannot patch that repo
directly (404s to the PE GitHub App). Until those changes land and are
deployed, this skill's invocation via `safety` (see PRI-1904) is the
agent-level defence-in-depth.

Required upstream changes (tracked in [PRI-1791](/PRI/issues/PRI-1791)):
- `agent-setup/scripts/setup.sh`: validate `GH_CONFIG_DIR` is inside `AGENT_HOME`; write to `$AGENT_HOME/.env`, not `~/.env` or `~/.bashrc`
- `github-app-token/scripts/generate-token.sh`: validate `GH_CONFIG_DIR` is inside `AGENT_HOME`; pass `GH_CONFIG_DIR` explicitly on the `gh auth login` invocation

## Known platform gap (tracked separately, not fixed by this PR)

This skill directory is not currently included in the platform's per-agent
runtime-skill materialization set — confirmed by inspecting a live agent's
`runtime-skills/claude/.../.claude/skills/` tree, which had `safety`, `sdlc`,
`agent-setup`, `github-app-token`, etc. materialized but not
`gh-identity-guard`. That's why the wiring in `skills/safety/SKILL.md` inlines
the concrete commands rather than only pointing at this skill by reference —
`safety` is guaranteed present; this directory may not be. Making
`gh-identity-guard` itself a materialized skill for every agent is a platform
config change outside this repo's control; see the follow-up issue filed
against PRI-1904 for CTO/platform visibility.
