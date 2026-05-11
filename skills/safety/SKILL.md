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

## If you are unsure

If you are unsure whether an action is safe, stop. Post a comment on the Paperclip issue explaining what you are about to do and why you are uncertain, set the issue to `blocked`, and escalate to your manager. Do not guess.
