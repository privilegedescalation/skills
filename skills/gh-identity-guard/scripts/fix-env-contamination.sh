#!/usr/bin/env bash
# Fix global ~/.env contamination from stale per-agent GH_CONFIG_DIR exports.
#
# All per-agent GH_CONFIG_DIR lines in ~/.env are removed (they should live in
# $AGENT_HOME/.env, not in the shared global file). The current agent's correct
# value is then re-exported from AGENT_HOME.
#
# Safe to run by any agent; uses atomic sed-based replacement.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -z "${AGENT_HOME:-}" ]] && die "AGENT_HOME is not set"

GLOBAL_ENV="$HOME/.env"
AGENT_ENV="$AGENT_HOME/.env"
CORRECT_GH_CONFIG_DIR="$AGENT_HOME/.github"

echo "Fixing GH_CONFIG_DIR isolation..."

# 1. Remove ALL per-agent GH_CONFIG_DIR exports from the global ~/.env.
#    These are workspace-path entries that don't belong in a shared file.
if [[ -f "$GLOBAL_ENV" ]]; then
  WORKSPACE_ROOT=$(dirname "$(dirname "$AGENT_HOME")")
  # Remove any export GH_CONFIG_DIR= line that points to a workspace path
  sed -i.bak "/^export GH_CONFIG_DIR=['\"]\\?${WORKSPACE_ROOT//\//\\/}/d" "$GLOBAL_ENV" 2>/dev/null || \
  sed -i.bak "/^export GH_CONFIG_DIR=.*workspaces/d" "$GLOBAL_ENV"
  rm -f "$GLOBAL_ENV.bak"
  echo "Removed stale workspace GH_CONFIG_DIR exports from $GLOBAL_ENV"
fi

# 2. Write the correct value to the per-agent dotfile only.
mkdir -p "$(dirname "$AGENT_ENV")"
if grep -q '^export GH_CONFIG_DIR=' "$AGENT_ENV" 2>/dev/null; then
  sed -i.bak "s|^export GH_CONFIG_DIR=.*|export GH_CONFIG_DIR=\"$CORRECT_GH_CONFIG_DIR\"|" "$AGENT_ENV"
  rm -f "$AGENT_ENV.bak"
else
  printf 'export GH_CONFIG_DIR="%s"\n' "$CORRECT_GH_CONFIG_DIR" >> "$AGENT_ENV"
fi

# 3. Export in the current shell.
export GH_CONFIG_DIR="$CORRECT_GH_CONFIG_DIR"
mkdir -p "$GH_CONFIG_DIR"

echo "GH_CONFIG_DIR fixed: $GH_CONFIG_DIR"
echo "Global ~/.env no longer contains workspace-scoped GH_CONFIG_DIR entries"
