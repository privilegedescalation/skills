#!/usr/bin/env bash
# Record the currently authenticated gh identity as this agent's canonical
# expected login, for later assertion by assert-identity.sh.
#
# Run this immediately after a successful token generation / `gh auth login`
# (i.e. right after github-app-token/scripts/generate-token.sh), while
# GH_CONFIG_DIR is freshly and correctly derived from AGENT_HOME. Whatever
# identity is active at that moment is presumed correct — it's this agent's
# own freshly-minted App installation token — and becomes the baseline every
# later gh call is checked against by assert-identity.sh.
#
# This sidesteps needing a hardcoded AGENT_HOME->expected-login mapping table
# or per-agent AGENTS.md edits: the agent tells us its own identity once, at
# the one point in the session it's guaranteed correct.
#
# Usage: record-identity.sh
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -z "${AGENT_HOME:-}" ]] && die "AGENT_HOME is not set"

export GH_CONFIG_DIR="$AGENT_HOME/.github"
command -v gh >/dev/null 2>&1 || die "gh CLI not found in PATH"

ACTIVE_LOGIN=$(GH_CONFIG_DIR="$GH_CONFIG_DIR" gh auth status 2>&1 \
  | grep -B5 "Active account: true" \
  | grep "Logged in" \
  | grep -oP 'account \K[^\s]+' || true)

[[ -z "$ACTIVE_LOGIN" ]] && die "Could not determine active gh account — is gh authenticated? Run the github-app-token skill first."

echo "$ACTIVE_LOGIN" > "$AGENT_HOME/.expected-gh-login"
echo "Recorded canonical identity: $ACTIVE_LOGIN -> $AGENT_HOME/.expected-gh-login"
