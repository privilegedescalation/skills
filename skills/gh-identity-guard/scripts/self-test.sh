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

# Test 4: no shared shell-init file contains a GH_CONFIG_DIR export
CONTAMINATED=0
for f in "$HOME/.env" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  if [[ -f "$f" ]] && grep -q '^export GH_CONFIG_DIR=' "$f" 2>/dev/null; then
    fail "$f still has a GH_CONFIG_DIR export:\n$(grep '^export GH_CONFIG_DIR=' "$f")"
    CONTAMINATED=1
  fi
done
if [[ "$CONTAMINATED" -eq 0 ]]; then
  pass "No shared shell-init file (~/.env, ~/.bashrc, ~/.bash_profile, ~/.profile) has a GH_CONFIG_DIR export"
else
  echo "  Fix: run scripts/fix-env-contamination.sh" >&2
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

# Test 6: record-identity.sh + assert-identity.sh round trip, and mismatch detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v gh >/dev/null 2>&1 && GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 | grep -q "Active account: true"; then
  if bash "$SCRIPT_DIR/record-identity.sh" >/dev/null 2>&1 && [[ -f "$AGENT_HOME/.expected-gh-login" ]]; then
    pass "record-identity.sh wrote $AGENT_HOME/.expected-gh-login"
    if bash "$SCRIPT_DIR/assert-identity.sh" >/dev/null 2>&1; then
      pass "assert-identity.sh (no arg) passes against the recorded baseline"
    else
      fail "assert-identity.sh (no arg) failed against its own just-recorded baseline"
    fi
    # Simulate cross-contamination: a different recorded login must be rejected.
    echo "some-other-agent-pe[bot]" > "$AGENT_HOME/.expected-gh-login.testbak"
    cp "$AGENT_HOME/.expected-gh-login" "$AGENT_HOME/.expected-gh-login.orig"
    mv "$AGENT_HOME/.expected-gh-login.testbak" "$AGENT_HOME/.expected-gh-login"
    if bash "$SCRIPT_DIR/assert-identity.sh" >/dev/null 2>&1; then
      fail "assert-identity.sh (no arg) did NOT reject a mismatched recorded login"
    else
      pass "assert-identity.sh (no arg) correctly rejects a mismatched recorded login"
    fi
    mv "$AGENT_HOME/.expected-gh-login.orig" "$AGENT_HOME/.expected-gh-login"
  else
    fail "record-identity.sh did not produce $AGENT_HOME/.expected-gh-login"
  fi
else
  echo "SKIP: gh not authenticated, skipping record/assert round-trip test"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] || exit 1
