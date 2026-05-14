---
name: uat
description: >
  Functional UAT procedures for Privileged Escalation Headlamp plugins. General
  behavior, acceptance criteria, artifact requirements, and reference to
  plugin-specific test steps in UAT_PLAYBOOK.md.
---

# UAT Procedures

## Purpose

This skill defines **functional User Acceptance Testing** for all Privileged Escalation Headlamp plugins. UAT validates that plugins work correctly in the deployed environment — by exercising plugin features in a running Headlamp instance, not by reviewing code or CI results.

## UAT Environment

The UAT Headlamp instance runs in the `headlamp-uat` Kubernetes namespace. Navigate to the Headlamp UAT URL using your Playwright browser. The plugin under test must be deployed to UAT before testing begins.

## General Process

For every `uat→main` promotion:

1. Open the Headlamp UAT instance in the browser
2. Confirm the plugin appears in the sidebar or app bar
3. Read the plugin's `UAT_PLAYBOOK.md` for the specific test steps to run
4. Execute the test steps from the playbook, capturing screenshots at each verification
5. Check the browser console for errors throughout
6. Post a structured test report (see Artifacts section)

## Acceptance Criteria

A plugin passes UAT when:

- **Plugin loads** — sidebar entry or app bar action is visible and accessible
- **Features work** — all core features in the playbook execute without errors
- **No console errors** — browser console shows no errors during normal operation
- **Data matches cluster state** — plugin data is consistent with `kubectl` queries against the cluster

A plugin fails UAT when:

- Plugin does not load or renders only an error state
- Any core feature is inaccessible or produces errors
- Console errors are present and not explainable as unrelated noise
- Displayed data contradicts known cluster state

## Artifact Requirements

For each plugin tested, the UAT report must include:

1. **Screenshots** of the plugin running in Headlamp — sidebar entry visible, main view loaded, at least one detail view
2. **Test checklist** — each step from `UAT_PLAYBOOK.md` marked pass/fail
3. **Console errors** — any browser console errors observed (attach screenshot if present)
4. **Environment info** — Headlamp version, plugin version, browser used, namespace context

## Reading UAT_PLAYBOOK.md

Each plugin repository contains a `UAT_PLAYBOOK.md` in its root directory. That file contains the canonical test steps for that specific plugin. Before running UAT, read the relevant playbook to know:

- Which features to exercise
- What the expected results are
- What screenshots to capture at each step

If `UAT_PLAYBOOK.md` does not exist for a plugin, treat that as a gap — report it in the UAT findings and flag it as a documentation issue.

## Decision Criteria

- **Approve** the `uat→main` promotion when all applicable test steps from the playbook pass and no console errors are present
- **Request changes** when any test step fails — include specific failing steps, observed results vs. expected results, and failure screenshots
- **Block** if the plugin fails to load entirely — escalate to CTO as a deployment issue requiring immediate resolution