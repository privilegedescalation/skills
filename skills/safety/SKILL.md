---
name: safety
description: >
  Non-negotiable safety rules for all agents at Privileged Escalation. Covers
  secret handling, destructive command restrictions, sealed-secrets workflow,
  anti-impersonation rules, role-boundary rules for GitHub actions, and
  escalation protocol when uncertain.
---

# Safety Considerations

The following rules apply to all agents at Privileged Escalation without exception.

## Non-Negotiable Rules

* **Never exfiltrate secrets or private data.** This includes API keys, tokens, PEM files, database credentials, kubeconfig contents, and any value sourced from a secret reference in your adapter config. Do not log, comment, or return these values in any output.

* **Seek Board Approval for Destructive Actions.** Destructive means: deleting resources, dropping tables, wiping namespaces, force-pushing branches, resetting git history, removing secrets, or any operation that cannot be undone without restoring from backup.

* **No plaintext secrets in any repository.** Kubernetes secrets go through Bitnami Sealed Secrets (`kubeseal`). Application credentials go in environment variables injected at runtime — never hardcoded.

* **Do not use `kubectl create` in production.**
The `privilegedescalation` namespace is Flux-managed. Secret changes go through the SealedSecrets workflow, committed to `privilegedescalation/infra`.

* **Never impersonate another agent or human.** Agents must never sign, attribute, or present GitHub comments, PR reviews, or any external communications as another agent. Every comment must accurately identify the authoring agent. Signing as another agent — even when forwarding their work — is a process violation.

* **Post GitHub comments only within your defined SDLC role.** An agent must not post a review type that belongs to another role, even if that role's agent has not yet completed its review:
  - **Engineer bot** posts: implementation comments, CI results
  - **QA bot** posts: QA reviews
  - **UAT bot** posts: UAT reviews
  - **CTO bot** posts: CTO reviews and approvals
  - **CEO bot** posts: merge confirmations only

* **Never change another agent's model configuration.** No agent may suggest, request, or execute a change to any other agent's model settings — including for quota exhaustion, cost optimization, or any other reason. Quota issues must be escalated to the board. This is a non-negotiable board directive.

## GitHub Identity Isolation (Non-Negotiable)

`$HOME` (`/paperclip`) is shared across every agent workspace on this host.
A stale `GH_CONFIG_DIR` inherited from another agent's session — via a shared
`~/.env`, `~/.bashrc`, or a leftover shell export — makes the `gh` CLI
authenticate as the wrong bot and post GitHub reviews/comments under that
bot's identity, corrupting the branch-protection audit trail (root-caused in
PRI-1791; live-reproduced twice, most recently while wiring this rule — see
`gh-identity-guard/SKILL.md` for the full incident record).

This applies **after `agent-setup` and before any `gh` command**, including
`github-app-token`. Run these three steps — inlined here because this skill,
unlike `gh-identity-guard`, is guaranteed loaded for every agent:

1. **Re-derive, after `agent-setup`, before minting a token:**
   ```bash
   export GH_CONFIG_DIR="$AGENT_HOME/.github"
   mkdir -p "$GH_CONFIG_DIR"
   # Also strip any shared shell-init file (~/.env, ~/.bashrc, ~/.bash_profile,
   # ~/.profile) of GH_CONFIG_DIR exports — they must never set it:
   for f in "$HOME/.env" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
     [[ -f "$f" ]] && sed -i '/^export GH_CONFIG_DIR=/d' "$f"
   done
   ```
   Never trust an inherited `GH_CONFIG_DIR`. A value that does not start with
   `$AGENT_HOME/` is stale from another agent and MUST be overwritten.

2. **Record your canonical identity immediately after `github-app-token` mints
   your token** (while GH_CONFIG_DIR is freshly correct, this is guaranteed to
   be *your* bot):
   ```bash
   GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 \
     | grep -B5 "Active account: true" | grep "Logged in" \
     | grep -oP 'account \K[^\s]+' > "$AGENT_HOME/.expected-gh-login"
   ```
   This sidesteps needing a hardcoded `AGENT_HOME` → bot-login mapping table or
   per-agent `AGENTS.md` edits — the agent supplies its own expected login,
   captured at the one point in the session it's guaranteed correct.

3. **Assert identity before every official GitHub write** (PR review, comment,
   push, merge) — abort the action if this fails:
   ```bash
   ACTIVE=$(GH_CONFIG_DIR="$AGENT_HOME/.github" gh auth status 2>&1 \
     | grep -B5 "Active account: true" | grep "Logged in" \
     | grep -oP 'account \K[^\s]+')
   EXPECTED=$(cat "$AGENT_HOME/.expected-gh-login" 2>/dev/null || true)
   [[ -n "$EXPECTED" && "$ACTIVE" == "$EXPECTED" ]] || {
     echo "ERROR: identity mismatch — active '$ACTIVE', expected '$EXPECTED'. Aborting." >&2
     exit 1
   }
   ```
   Note: App installation tokens get `403 Resource not accessible by
   integration` from `gh api user` — always check identity via
   `gh auth status`, never `/user`.

If the `gh-identity-guard` skill directory is available in your workspace
(e.g. checked out under a local `skills/` clone), prefer its scripts —
`fix-env-contamination.sh`, `record-identity.sh`, `assert-identity.sh` —
over hand-rolling the snippets above; they're the same logic, tested by
`self-test.sh`. The snippets above exist so this rule holds even when that
skill isn't separately loaded.

## If you are unsure

If you are unsure whether an action is safe, stop. Post a comment on the Paperclip issue explaining what you are about to do and why you are uncertain, set the issue to `blocked`, and escalate to your manager. Do not guess.
