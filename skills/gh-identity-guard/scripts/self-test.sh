#!/usr/bin/env bash
# Self-test: verify two agents running in sequence cannot cross-contaminate
# GH_CONFIG_DIR. Run this to validate the isolation guarantee.
#
# Usage: bash self-test.sh
# Exit 0 = all checks pass; non-zero = failure details printed to stderr
set -euo pipefail

PASS=0
FAIL=0

pass() { echo "PASS: $*"; ((PASS++)) || true; }
fail() { echo "FAIL: $*" >&2; ((FAIL++)) || true; }

[[ -z "${AGENT_HOME:-}" ]] && { echo "ERROR: AGENT_HOME not set" >&2; exit 1; }

echo "=== gh-identity-guard self-test ==="

# Test 1: GH_CONFIG_DIR re-derive always wins over inherited stale value
STALE_PATH="/paperclip/instances/default/workspaces/FAKE-OTHER-AGENT/.github"
SAVED_GH_CONFIG_DIR="${GH_CONFIG_DIR:-}"
export GH_CONFIG_DIR="$STALE_PATH"

# Simulate what setup should do
export GH_CONFIG_DIR="$AGENT_HOME/.github"

if [[ "$GH_CONFIG_DIR" == "$AGENT_HOME/.github" ]]; then
  pass "Re-derive overrides stale inherited GH_CONFIG_DIR"
else
  fail "GH_CONFIG_DIR is '$GH_CONFIG_DIR', expected '$AGENT_HOME/.github'"
fi
export GH_CONFIG_DIR="$AGENT_HOME/.github"  # always restore to the correct value, never back to a potentially stale saved value

# Test 2: GH_CONFIG_DIR is inside AGENT_HOME
if [[ "$GH_CONFIG_DIR" == "$AGENT_HOME"* ]]; then
  pass "GH_CONFIG_DIR is inside AGENT_HOME"
else
  fail "GH_CONFIG_DIR '$GH_CONFIG_DIR' is NOT inside AGENT_HOME '$AGENT_HOME'"
fi

# Test 3: Per-agent .env exists and has correct GH_CONFIG_DIR
AGENT_ENV="$AGENT_HOME/.env"
if [[ -f "$AGENT_ENV" ]]; then
  if grep -q "^export GH_CONFIG_DIR=\"$AGENT_HOME/.github\"" "$AGENT_ENV" 2>/dev/null || \
     grep -q "^export GH_CONFIG_DIR=$AGENT_HOME/.github" "$AGENT_ENV" 2>/dev/null; then
    pass "Per-agent .env has correct GH_CONFIG_DIR"
  else
    STORED=$(grep "^export GH_CONFIG_DIR=" "$AGENT_ENV" || echo "not found")
    fail "Per-agent .env GH_CONFIG_DIR is wrong: '$STORED'"
  fi
else
  fail "Per-agent .env not found at $AGENT_ENV"
fi

# Test 4: Global ~/.env does NOT contain workspace-scoped GH_CONFIG_DIR entries
GLOBAL_ENV="$HOME/.env"
if [[ -f "$GLOBAL_ENV" ]]; then
  WORKSPACE_ROOT=$(dirname "$(dirname "$AGENT_HOME")")
  CONTAMINATION=$(grep "^export GH_CONFIG_DIR=.*workspaces" "$GLOBAL_ENV" 2>/dev/null || true)
  if [[ -z "$CONTAMINATION" ]]; then
    pass "Global ~/.env has no workspace-scoped GH_CONFIG_DIR (no contamination)"
  else
    fail "Global ~/.env still has contaminated entries:\n$CONTAMINATION"
    echo "  Fix: run scripts/fix-env-contamination.sh" >&2
  fi
else
  pass "Global ~/.env does not exist (no contamination risk)"
fi

# Test 5: gh CLI uses per-agent config dir
if command -v gh >/dev/null 2>&1; then
  AUTH_OUTPUT=$(GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 || true)
  if echo "$AUTH_OUTPUT" | grep -q "Active account: true"; then
    ACTIVE=$(echo "$AUTH_OUTPUT" | grep -B5 "Active account: true" | grep "Logged in" | grep -oP 'account \K[^\s]+' || echo "unknown")
    pass "gh CLI authenticated in per-agent config dir (active: $ACTIVE)"
  else
    fail "gh CLI is not authenticated in $AGENT_HOME/.github — run github-app-token skill first"
  fi
else
  echo "SKIP: gh CLI not found, skipping auth test"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
