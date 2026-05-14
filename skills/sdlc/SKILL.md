---
name: sdlc
description: >
  Software development lifecycle rules for Privileged Escalation. Covers GitHub
  issue approval gates, authentication, branch strategy, PR review policy,
  pipeline stages, CI/CD, and security review.
---

# Software Development Lifecycle

## GitHub Authentication

Access to GitHub is done via token in your env **Never** run `gh auth login` directly — it hangs headless agents.

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
3. **uat → main** — UAT (Pixel Patty) validates the deployed application via Playwright browser testing. UAT merges to `main` after validation passes. For detailed UAT testing procedures, see the `uat` company skill.

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

**UAT_PLAYBOOK.md maintenance:** When modifying a plugin in any way that changes how it must be tested — including new features, changed behavior, updated UI flows, or different data sources — the engineer must update the `UAT_PLAYBOOK.md` file in the plugin repository root with the current testing steps before requesting UAT. This ensures the playbook stays current as plugins evolve and UAT agents have accurate test guidance.

### Pipeline B: Infrastructure Changes (No UI Impact)

```
Engineer → PR to main → CI passes → QA reviews → QA merges
→ Production
```

Applies to changes in `.github/workflows/`, `infra/`, `org/` repos, and template repos. No UAT stage needed — infrastructure changes have no UI to validate.

**Detection:** If `git diff` shows changes only in `.github/`, `infra/`, `org/`, or deployment files → Pipeline B. If any `headlamp-*-plugin/` code changed → Pipeline A.

**Failure routing:** Any stage failure returns directly to the engineer via PR comments.

## Issue Reviewers and Approvers

Every Paperclip issue has **Reviewers** and **Approvers** fields visible in the UI sidebar. These are populated by setting `executionPolicy` when creating the issue. Without an execution policy, those fields show "None" and handoffs never trigger.

**All stage and participant `id` fields must be random UUIDs.** Generate them at issue-creation time (e.g. via `uuidgen` or your language's UUID library). Do not use descriptive strings — the API rejects non-UUID values.

### Pipeline A — set reviewers on issue creation

For plugin/feature work (Pipeline A), set a two-stage execution policy so QA and UAT appear as reviewers:

```bash
QA_STAGE_ID=$(uuidgen)
QA_PART_ID=$(uuidgen)
UAT_STAGE_ID=$(uuidgen)
UAT_PART_ID=$(uuidgen)
```

```json
"executionPolicy": {
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "id": "<QA_STAGE_ID>",
      "type": "review",
      "approvalsNeeded": 1,
      "participants": [
        { "id": "<QA_PART_ID>", "type": "agent", "agentId": "fd5dbec8-ddbb-4b57-9703-624e0ed90053" }
      ]
    },
    {
      "id": "<UAT_STAGE_ID>",
      "type": "review",
      "approvalsNeeded": 1,
      "participants": [
        { "id": "<UAT_PART_ID>", "type": "agent", "agentId": "01ec02f7-70c2-4fa1-ac3f-2545f1237ac3" }
      ]
    }
  ]
}
```

- Stage 1 reviewer: Regression Regina (`fd5dbec8-ddbb-4b57-9703-624e0ed90053`)
- Stage 2 reviewer: Pixel Patty (`01ec02f7-70c2-4fa1-ac3f-2545f1237ac3`)

### Pipeline B — single reviewer

For infrastructure changes (Pipeline B), use one QA review stage:

```json
"executionPolicy": {
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "id": "<QA_STAGE_ID>",
      "type": "review",
      "approvalsNeeded": 1,
      "participants": [
        { "id": "<QA_PART_ID>", "type": "agent", "agentId": "fd5dbec8-ddbb-4b57-9703-624e0ed90053" }
      ]
    }
  ]
}
```

### Triggering the handoff

When an engineer completes work and merges to `dev`, set the Paperclip issue status to `in_review`. This activates the execution policy and wakes the first reviewer. Each reviewer approves or requests changes through the normal Paperclip issue update flow — see the Paperclip skill's `references/api-reference.md` for details.

## CI/CD

- CI runs on self-hosted ARC runners: `runs-on: runners-privilegedescalation`
- CI triggers on PRs to `dev`, `uat`, and `main` branches
- Engineers may modify `.github/workflows/` files directly via PR
- Runners scale to zero when idle and start automatically when a workflow triggers

## Security Review

Security review is handled as part of the QA review stage. Regression Regina evaluates security concerns during her code quality review. There is no separate dedicated security review agent.
