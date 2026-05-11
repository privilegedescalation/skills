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

All plugin repositories use three long-lived branches representing a promotion chain:

| Branch | Environment | Owner | Who merges to it |
|--------|-------------|-------|-----------------|
| `dev` | Development | Engineer | Engineer self-merges after CI passes |
| `uat` | User Acceptance Testing | QA (Regression Regina) | QA merges after code review |
| `main` | Production | UAT (Pixel Patty) | UAT merges after browser validation |

**Engineers target `dev` via feature branches** — never push directly to any long-lived branch.

Feature branches follow the convention: `<agent-name>/<short-description>` (e.g., `gandalf/add-sealed-secrets-list`).

## Pull Requests

All changes must happen via pull request. Always include `cc @cpfarhood` at the bottom of the PR body for visibility — not as a reviewer.

```bash
gh pr create --title "..." --body "... cc @cpfarhood"
```

## PR Review & Merge Policy

**Do not approve a PR with failing tests, type errors, or no coverage for new code.**

### Promotion chain

Each promotion is a PR reviewed and merged by its gate owner:

1. **feature → dev** — Engineer self-merges after CI passes. No review required. Dev is for validation, not quality gates.
2. **dev → uat** — QA (Regression Regina) reviews code quality: test coverage, regressions, edge cases. QA merges to `uat` after approval.
3. **uat → main** — UAT (Pixel Patty) validates the deployed application via Playwright browser testing. UAT merges to `main` after validation passes.

**Each gate owner has merge authority.** No separate merge step by another role. No agent merges their own code to `uat` or `main` — only the gate owner merges promotions they review.

## Pipeline

### Pipeline A: Plugin/Feature Changes

```
Engineer → PR to dev → self-merge → deploys to dev
→ Engineer validates on dev
→ PR from dev → uat → QA reviews → QA merges
→ Deploys to UAT environment
→ PR from uat → main → UAT validates → UAT merges
→ Production
```

Applies to changes in `headlamp-*-plugin/` repos (plugin code, features, bug fixes).

### Pipeline B: Infrastructure Changes (No UI Impact)

```
Engineer → PR to main → CI passes → QA reviews → QA merges
→ Production
```

Applies to changes in `.github/workflows/`, `infra/`, `org/` repos, and template repos. No UAT stage needed — infrastructure changes have no UI to validate.

**Detection:** If `git diff` shows changes only in `.github/`, `infra/`, `org/`, or deployment files → Pipeline B. If any `headlamp-*-plugin/` code changed → Pipeline A.

**Failure routing:** Any stage failure returns directly to the engineer via PR comments.

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
- CI triggers on PRs to `dev`, `uat`, and `main` branches
- Engineers may modify `.github/workflows/` files directly via PR
- Runners scale to zero when idle and start automatically when a workflow triggers

## Security Review

Security review is handled as part of the QA review stage. Regression Regina evaluates security concerns during her code quality review. There is no separate dedicated security review agent.
