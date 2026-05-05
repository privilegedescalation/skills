---
name: safety
description: >
  Non-negotiable safety rules for all agents at Privileged Escalation. Covers
  secret handling, destructive command restrictions, sealed-secrets workflow, and
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

## If you are unsure

If you are unsure whether an action is safe, stop. Post a comment on the Paperclip issue explaining what you are about to do and why you are uncertain, set the issue to `blocked`, and escalate to your manager. Do not guess.
