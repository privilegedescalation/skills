#!/usr/bin/env bash
# Fix shared shell-init contamination from stale per-agent GH_CONFIG_DIR exports.
#
# $HOME (/paperclip) is shared across every agent workspace on this host, and
# several files under it are sourced automatically by new shells:
#   - $HOME/.env        (some agents historically appended per-agent exports here)
#   - $HOME/.bashrc      (sourced on every new interactive/login-style shell)
#   - $HOME/.bash_profile
#   - $HOME/.profile
# Any of these accumulating an `export GH_CONFIG_DIR=.../workspaces/<other-agent>/.github`
# line silently hands every subsequent agent shell the wrong bot's config dir —
# this is the exact root cause reproduced in PRI-1791/PRI-1904. GH_CONFIG_DIR
# must never live in a shared file; it belongs only in $AGENT_HOME/.env.
#
# All GH_CONFIG_DIR export lines are stripped from the shared files below, and
# the current agent's correct value is (re)written to its own per-agent
# dotfile and exported into the current shell.
#
# Safe to run by any agent; uses atomic sed-based replacement.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -z "${AGENT_HOME:-}" ]] && die "AGENT_HOME is not set"

AGENT_ENV="$AGENT_HOME/.env"
CORRECT_GH_CONFIG_DIR="$AGENT_HOME/.github"

echo "Fixing GH_CONFIG_DIR isolation..."

# 1. Strip ALL GH_CONFIG_DIR exports from shared shell-init files. GH_CONFIG_DIR
#    is per-agent state and must never be set in a file every agent's shell
#    sources — it belongs only in $AGENT_HOME/.env.
for SHARED_FILE in "$HOME/.env" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  if [[ -f "$SHARED_FILE" ]] && grep -q '^export GH_CONFIG_DIR=' "$SHARED_FILE" 2>/dev/null; then
    sed -i.bak '/^export GH_CONFIG_DIR=/d' "$SHARED_FILE"
    rm -f "$SHARED_FILE.bak"
    echo "Removed stale GH_CONFIG_DIR export(s) from shared file: $SHARED_FILE"
  fi
done

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
echo "No shared shell-init file under \$HOME contains a workspace-scoped GH_CONFIG_DIR export"
