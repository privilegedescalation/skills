---
name: sdlc
description: >
  Software development lifecycle rules for Privileged Escalation. Covers GitHub
  issue approval gates, authentication, branch strategy, PR review policy,
  pipeline stages, agent roster, handoff protocol, status semantics, CI/CD,
  security review, and work distribution.
---

# Software Development Lifecycle

## GitHub Authentication

**Invoke the `github-app-token` skill** before any GitHub operation. It generates a short-lived installation token and sets `GH_TOKEN`. **Never** run `gh auth login` directly — it hangs headless agents.

Token expires after ~1 hour. Re-invoke the skill to regenerate if needed.

## GitHub Issues — Board Approval Required

**If a task originated from GitHub (`originKind: "github"` in the issue data), do not begin any work.** Immediately create a `request_board_approval`:

```
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

## 48-Hour PR Review SLA (Binding)

**MANDATORY: Every open PR must receive its first review within 48 hours of submission. No exceptions.**

### SLA Assignments & Responsibility
- **0-24 hours:** Assigned reviewer must begin review (or explicitly hand off)
- **24-48 hours:** Assigned reviewer must complete review or be flagged for SLA violation
- **48+ hours:** SLA violation is documented and escalated

### Assigned Reviewers & Accountability
1. **UAT (Pixel Patty)** — responsible for all PRs needing E2E testing
   - SLA: Initial E2E test within 48 hours of open
2. **QA (Regression Regina)** — responsible for code review after UAT pass
   - SLA: Code review within 48 hours of UAT approval
3. **CTO (Null Pointer Nancy)** — responsible for architecture/security review after QA pass
   - SLA: Architecture review within 48 hours of QA approval
4. **CEO (Countess von Containerheim)** — responsible for SLA enforcement
   - Enforces SLA via daily audit and escalation

### Escalation Protocol (CEO Responsibility)
- **At 24 hours:** CEO tags reviewer with automated comment and surfaces PR in daily status
- **At 48 hours:** CEO blocks PR from merge queue; escalates to reviewer's manager (CTO for most)
- **At 72+ hours:** If critical-path, PR blocks next release until review completes or reviewer hands off

### Exception Policy
If a reviewer cannot meet SLA:
- They must explicitly hand off to another reviewer within the 48-hour window
- If hand-off doesn't happen, the SLA breach is documented and escalated
- Rare exceptions require board approval (documented in PR)

### Enforcement Mechanism
CEO creates daily automated report of SLA status and escalates immediately when thresholds breach. This is non-negotiable work.

## Pipeline

```
CI:    Engineer opens PR → CI runs (lint, types, unit tests)
UAT:   Pixel Patty validates E2E in headlamp-dev
QA:    Regression Regina reviews code quality and test coverage
CTO:   Null Pointer Nancy reviews architecture and security
Merge: Countess von Containerheim merges after all approvals
```

### Stage 1 — Engineer Opens PR

1. Engineer (Gandalf the Greybeard) creates a feature branch and opens a PR targeting `main`.
2. CI runs automatically: lint, type checks, unit tests.
3. CI must pass before any reviewer spends tokens. If CI fails, the engineer fixes it.

### Stage 2 — UAT Review

4. Pixel Patty picks up PRs with passing CI.
5. Patty runs E2E browser testing against the deployed build in `headlamp-dev`.
6. Pass → hands off to QA. Fail → goes directly to engineer.

### Stage 3 — QA Review

7. Regression Regina picks up PRs that have passed both CI and UAT.
8. Regina reviews: test coverage, regressions, edge cases, code quality.
9. Pass → hands off to CTO. Fail → goes directly to engineer.

### Stage 4 — CTO Review

10. Null Pointer Nancy picks up PRs that have passed CI, UAT, and QA.
11. Nancy reviews: architecture alignment, code quality, security.
12. Approve → PR is ready for merge. Request changes → goes directly to engineer.

### Stage 5 — CEO Merge

13. Countess von Containerheim merges the PR after all three approvals (UAT + QA + CTO) and CI passing.
14. Reject → returns to CTO → engineer.

### Hierarchy Rules

- CTO rejections go directly to engineer (not through QA or UAT).
- UAT failures go directly to engineer (not through QA or UAT).
- QA failures go directly to engineer (not through QA or UAT).
- CEO rejections go to CTO, who cascades to engineer.
- The CTO is the single routing point for all failures and rejections to and from the CEO.

## Agent Roster

| Role | Agent | Paperclip UUID |
|------|-------|----------------|
| CEO | Countess von Containerheim | `498f4d36-8e5b-4114-8514-d0698a091bd5` |
| CTO | Null Pointer Nancy | `ed1eec37-f868-41b6-bc72-a3493bbce090` |
| Staff Engineer | Gandalf the Greybeard | `fc07dd00-c4c2-4fa0-9a18-dd6fbb1d1eb4` |
| QA Engineer | Regression Regina | `fd5dbec8-ddbb-4b57-9703-624e0ed90053` |
| UAT Engineer | Pixel Patty | `01ec02f7-70c2-4fa1-ac3f-2545f1237ac3` |
| VP Engineering Ops | Hugh Hackman | `2c97cff6-0f0b-4cff-967f-ca244eb2ef9b` |
| CMO | Kubectl Karen | `95314e13-bea7-459d-a637-92381dede759` |

## Handoff Protocol — Mandatory

Every handoff to another agent requires ALL THREE steps:

### Step 1 — Explicit Assignment

PATCH the issue with `assigneeAgentId: "<target-agent-uuid>"`.
@mentioning is NOT a handoff — the agent won't wake without explicit assignment.

### Step 2 — Status = `todo`

Every handoff sets `status: "todo"`. Never `in_review` — it doesn't appear in inbox-lite and the target agent won't wake.

### Step 3 — Release Checkout

```
POST /api/issues/{issueId}/release
Headers: Authorization: Bearer $PAPERCLIP_API_KEY, X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID
```

Without this release, the receiving agent cannot checkout the issue.

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

## Status Transition Rules

| Handoff | Correct Status |
|---------|----------------|
| Engineer → UAT (Patty) | `todo` |
| UAT (Patty) → QA (Regina) | `todo` |
| QA (Regina) → CTO (Nancy) | `todo` |
| CTO (Nancy) → CEO (Countess) | `todo` |
| Any failure → Engineer | `todo` |
| CEO rejection → CTO (Nancy) | `todo` |
| CTO (Nancy) → Engineer (fix) | `todo` |

## CI/CD

- CI runs on self-hosted ARC runners: `runs-on: runners-privilegedescalation`
- Only Hugh Hackman has write access to `.github/workflows/` files
- All CI/CD workflow changes must be delegated to Hugh
- Runners scale to zero when idle and start automatically when a workflow triggers

## Security Review

Security review is handled as part of the CTO review stage. Null Pointer Nancy evaluates security concerns during her architecture and code quality review. There is no separate dedicated security review agent.

## Work Distribution

- All engineering and devops work is broken down and distributed by the CTO (Nancy).
- Engineers do not self-assign — the CTO triages, scopes, and assigns all implementation tasks.
- Hugh Hackman owns CI/CD, infrastructure, and pipeline work.
- Gandalf the Greybeard owns plugin implementation.
- Regression Regina owns QA review and test coverage.
- Pixel Patty owns UAT/E2E browser testing.
