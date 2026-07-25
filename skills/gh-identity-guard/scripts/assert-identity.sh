#!/usr/bin/env bash
# Assert that the currently authenticated gh CLI identity matches the expected
# bot login. Exits non-zero with a clear error if there is a mismatch.
#
# Usage: assert-identity.sh [expected-gh-login]
# Example: assert-identity.sh "hugh-hackman-pe[bot]"
#
# If no argument is given, falls back to the login recorded in
# $AGENT_HOME/.expected-gh-login by record-identity.sh (written right after
# github-app-token mints this agent's own token). This avoids needing a
# hardcoded AGENT_HOME->login mapping or per-agent AGENTS.md edits: whatever
# identity this agent generated its own token as, at the point it generated
# it, becomes the baseline every later gh call is checked against.
#
# Requires: GH_CONFIG_DIR to be correctly set to $AGENT_HOME/.github
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

EXPECTED_LOGIN="${1:-}"

# --- Validate GH_CONFIG_DIR is under AGENT_HOME ---
if [[ -z "${AGENT_HOME:-}" ]]; then
  die "AGENT_HOME is not set — cannot validate GH_CONFIG_DIR isolation"
fi

# Fall back to the recorded canonical identity for this agent, if no explicit
# expected login was passed in.
if [[ -z "$EXPECTED_LOGIN" && -f "$AGENT_HOME/.expected-gh-login" ]]; then
  EXPECTED_LOGIN=$(cat "$AGENT_HOME/.expected-gh-login")
fi

# Re-derive GH_CONFIG_DIR defensively; never trust an inherited value
EXPECTED_GH_CONFIG_DIR="$AGENT_HOME/.github"
if [[ "${GH_CONFIG_DIR:-}" != "$EXPECTED_GH_CONFIG_DIR" ]]; then
  warn "GH_CONFIG_DIR was '$GH_CONFIG_DIR', overriding with '$EXPECTED_GH_CONFIG_DIR'"
  export GH_CONFIG_DIR="$EXPECTED_GH_CONFIG_DIR"
fi
mkdir -p "$GH_CONFIG_DIR"

# --- Check gh is available ---
command -v gh >/dev/null 2>&1 || die "gh CLI not found in PATH"

# --- Get active account ---
# gh auth status output format (example):
#   ✓ Logged in to github.com account hugh-hackman-pe[bot] (...)
#     - Active account: true
ACTIVE_LOGIN=$(GH_CONFIG_DIR="$GH_CONFIG_DIR" gh auth status 2>&1 \
  | awk '/Active account: true/{found=1} found && /Logged in/{print; exit}' \
  | grep -oP 'account \K[^\s]+' || true)

# Fallback: parse active account from the structured output
if [[ -z "$ACTIVE_LOGIN" ]]; then
  ACTIVE_LOGIN=$(GH_CONFIG_DIR="$GH_CONFIG_DIR" gh auth status 2>&1 \
    | grep -E "Active account: true" -A 0 -B 5 \
    | grep "Logged in" \
    | grep -oP 'account \K[^\s]+' || true)
fi

# Second fallback: find account line with Active account: true
if [[ -z "$ACTIVE_LOGIN" ]]; then
  AUTH_STATUS=$(GH_CONFIG_DIR="$GH_CONFIG_DIR" gh auth status 2>&1 || true)
  # Extract lines: the account login line immediately before "Active account: true"
  ACTIVE_LOGIN=$(echo "$AUTH_STATUS" \
    | grep -B3 "Active account: true" \
    | grep "Logged in" \
    | sed 's/.*account \([^ ]*\).*/\1/' || true)
fi

if [[ -z "$ACTIVE_LOGIN" ]]; then
  die "Could not determine active gh account. Run 'GH_CONFIG_DIR=$GH_CONFIG_DIR gh auth status' to diagnose."
fi

echo "Active gh identity: $ACTIVE_LOGIN (GH_CONFIG_DIR=$GH_CONFIG_DIR)"

# --- Assert against expected login ---
if [[ -n "$EXPECTED_LOGIN" ]]; then
  if [[ "$ACTIVE_LOGIN" != "$EXPECTED_LOGIN" ]]; then
    die "Identity mismatch! Expected '$EXPECTED_LOGIN' but active account is '$ACTIVE_LOGIN'. \
Aborting to prevent posting under the wrong bot identity. \
Re-run 'github-app-token' skill with GH_CONFIG_DIR=$GH_CONFIG_DIR to refresh auth."
  fi
  echo "Identity verified: $ACTIVE_LOGIN matches expected $EXPECTED_LOGIN"
else
  warn "No expected login provided or recorded — run record-identity.sh right after minting this agent's token so future calls have a baseline to check against."
  echo "No expected login available — identity check skipped (active: $ACTIVE_LOGIN)"
fi
