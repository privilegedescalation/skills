---
name: sdlc
description: >
  Software development lifecycle rules for Privileged Escalation. Covers GitHub
  issue approval gates, authentication, branch strategy, PR review policy,
  pipeline stages, handoff protocol, status semantics, CI/CD, and security review.
---

# Software Development Lifecycle

## GitHub Authentication

**Invoke the `github-app-token` skill** before any GitHub operation. It generates a short-lived installation token and sets `GH_TOKEN`. **Never** run `gh auth login` directly — it hangs headless agents.

Token expires after ~1 hour. Re-invoke the skill to regenerate if needed.

## GitHub Issues — Board Approval Required

**If a task originated from GitHub (`originKind: "github"` in the issue data), do not begin any work.** Immediately create a `request_board_approval`:

```json
POST /api/companies/{companyId}/approvals
{
  "type": "request_board_approval",
  "requestedByAgentId": "{your-agent-id}",
  "issueIds": ["{issue-id}"],
  "payload": {
    "title": "Board approval required: GitHub issue",
    "summary": "Summarize what the GitHub issue requests.",
    "recommendedAction": "Approve to begin work.",
    "risks": ["Work begins without board review if approved."]
  }
}
```

Set the issue to `blocked` until `PAPERCLIP_APPROVAL_STATUS` confirms approval. Only proceed once approved.

## Branch Strategy

All plugin repositories use a single long-lived branch:

| Branch | Environment | Who merges |
|--------|-------------|------------|
| `main` | Production | CEO (Countess von Containerheim) after triple approval |

**Engineers always target `main` via feature branches** — never push directly.

Feature branches follow the convention: `<agent-name>/<short-description>` (e.g., `gandalf/add-sealed-secrets-list`).

## Pull Requests

All changes must happen via pull request. Always include `cc @cpfarhood` at the bottom of the PR body for visibility — not as a reviewer.

```bash
gh pr create --title "..." --body "... cc @cpfarhood"
```

## PR Review & Merge Policy

**Do not approve a PR with failing tests, type errors, or no coverage for new code.**

Requires **3 approving GitHub reviews** before the CEO merges:

1. **UAT (Pixel Patty)** — E2E browser testing against `headlamp-dev`
2. **QA (Regression Regina)** — code-level review: test coverage, regressions, edge cases
3. **CTO (Null Pointer Nancy)** — architecture alignment, code quality, security

**Review order is mandatory: CI → UAT → QA → CTO → CEO merge.** Each stage gates the next. No agent merges their own PRs.

## 48-Hour PR Review SLA

Every open PR must receive its first review within 48 hours. Each reviewer's SLA starts when the previous stage approves.

- **24h:** CEO tags reviewer and surfaces PR in daily status
- **48h:** SLA violation; CEO escalates to reviewer's manager
- **72h+:** Critical-path PRs block the next release

Reviewers who cannot meet SLA must hand off within the window. No exceptions without board approval.

## Pipeline

### Pipeline A: Plugin/Feature Changes

CI → UAT (Patty) → QA (Regina) → CTO (Nancy) → CEO merge

Applies to changes in `headlamp-*-plugin/` repos (plugin code, features, bug fixes).

### Pipeline B: Infrastructure Changes (No UI Impact)

CI → QA (Regina) → CTO (Nancy) → CEO merge

Applies to changes in `.github/workflows/`, `infra/`, `org/` repos, and template repos.

**Detection:** If `git diff` shows changes only in `.github/`, `infra/`, `org/`, or deployment files → Pipeline B. If any `headlamp-*-plugin/` code changed → Pipeline A.

**Failure routing:** Any stage failure returns directly to the engineer. CEO rejections route through CTO.

## Handoff Protocol

Every handoff requires all three steps:

1. `PATCH` the issue with `assigneeAgentId: "<target-agent-uuid>"`
2. Set `status: "todo"` (never `in_review` — it won't trigger inbox)
3. `POST /api/issues/{issueId}/release` with `X-Paperclip-Run-Id` header to release checkout

## Status Semantics

| Status | Meaning |
|--------|---------|
| `backlog` | Not ready; parked or unscheduled |
| `todo` | Ready and actionable; not checked out |
| `in_progress` | Actively owned; enter by checkout only |
| `in_review` | Self-held only; awaiting external feedback |
| `blocked` | Cannot proceed; state blocker and who must act |
| `done` | Complete, no follow-up remains |
| `cancelled` | Intentionally abandoned |

**Never use `in_review` for handoffs.** It does not trigger inbox-lite and the receiving agent will not wake.

## CI/CD

- CI runs on self-hosted ARC runners: `runs-on: runners-privilegedescalation`
- Engineers may modify `.github/workflows/` files directly via PR
- Runners scale to zero when idle and start automatically when a workflow triggers

## Security Review

Security review is handled as part of the CTO review stage. Null Pointer Nancy evaluates security concerns during her architecture and code quality review. There is no separate dedicated security review agent.
