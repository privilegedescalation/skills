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

## Headlamp Version Source of Truth

When recording or verifying the Headlamp version, the **authoritative source is the deployed image**, not the in-app dialog:

- Cite the deployment's image tag/digest — the `app.kubernetes.io/version` label and the container image ref/digest (e.g. `ghcr.io/.../headlamp@sha256:...`) — as the authoritative Headlamp version in UAT evidence.
- **Do not** treat Headlamp's in-app "About / build information" dialog as authoritative. Its reported build version can lag the deployed image tag — an upstream build-metadata quirk; PE does not build Headlamp core (observed 0.41.0 in the in-app dialog vs v0.42.0 on the image/labels).
- A discrepancy between the in-app build-info dialog and the image tag is **not**, by itself, a UAT failure. Record the image tag/digest and proceed.

## General Process

For every `uat→main` promotion:

1. Open the Headlamp UAT instance in the browser
2. Confirm the plugin appears in the sidebar or app bar
3. Read the plugin's `UAT_PLAYBOOK.md` for the specific test steps to run
4. Execute the test steps from the playbook, capturing screenshots at each verification
5. Check the browser console for errors throughout — excluding the documented viewer-role RBAC 403 allow-list (see Console Errors and the Viewer-Role 403 Baseline)
6. Post a structured test report (see Artifacts section)

## Acceptance Criteria

A plugin passes UAT when:

- **Plugin loads** — sidebar entry or app bar action is visible and accessible
- **Features work** — all core features in the playbook execute without errors
- **No unexpected console errors** — browser console shows no errors during normal operation other than the documented viewer-role RBAC 403 allow-list (see Console Errors and the Viewer-Role 403 Baseline)
- **Data matches cluster state** — plugin data is consistent with `kubectl` queries against the cluster

A plugin fails UAT when:

- Plugin does not load or renders only an error state
- Any core feature is inaccessible or produces errors
- Console errors are present that are **not** on the documented viewer-role 403 allow-list and not explainable as unrelated noise
- Displayed data contradicts known cluster state

## Console Errors and the Viewer-Role 403 Baseline

The UAT Headlamp instance authenticates as the `headlamp-uat/headlamp-uat-viewer` service account, which is **intentionally namespace-scoped** (ClusterRole `view` bound to namespace `headlamp-uat`, plus a few cluster-scoped read verbs: `namespaces`, `persistentvolumes`, `storageclasses`, and sealedsecrets/secrets in `headlamp-uat`). Headlamp's Overview / Workloads / Services / Custom Resources pages probe cluster-wide resources the viewer is not granted, so the browser console logs **expected** `403 Forbidden` responses. The pages still render.

These 403s are a documented baseline, not defects. Do not fail UAT for them, and do not request a widening of the viewer SA — its least-privilege RBAC is deliberate and lives in `cpfarhood/kubernetes`, which PE cannot modify.

### Expected viewer-role 403 allow-list

Console `403 Forbidden` entries for the namespace-scoped viewer identity (`system:serviceaccount:headlamp-uat:headlamp-uat-viewer`) are expected for:

- cluster-wide `nodes`
- cluster-wide `pods`
- cluster-wide `events`
- `metrics.k8s.io/nodes`
- cluster CRD discovery

Example message:

> `events is forbidden: User "system:serviceaccount:headlamp-uat:headlamp-uat-viewer" cannot list resource "events" in API group "" at the cluster scope`

### Scenarios that need cluster-wide views

If a UAT scenario genuinely requires cluster-wide resource views, use the per-session `headlamp-uat-reader` service account (PRI-1957, in flight to CEO/platform) — **not** the viewer SA, and **not** a widening of viewer RBAC.

## Artifact Requirements

For each plugin tested, the UAT report must include:

1. **Screenshots** of the plugin running in Headlamp — sidebar entry visible, main view loaded, at least one detail view
2. **Test checklist** — each step from `UAT_PLAYBOOK.md` marked pass/fail
3. **Console errors** — any browser console errors observed (attach screenshot if present)
4. **Environment info** — Headlamp version (cite the deployment image tag/digest and `app.kubernetes.io/version` label as authoritative, not the in-app build-info dialog — see Headlamp Version Source of Truth), plugin version, browser used, namespace context

## Reading UAT_PLAYBOOK.md

Each plugin repository contains a `UAT_PLAYBOOK.md` in its root directory. That file contains the canonical test steps for that specific plugin. Before running UAT, read the relevant playbook to know:

- Which features to exercise
- What the expected results are
- What screenshots to capture at each step

If `UAT_PLAYBOOK.md` does not exist for a plugin, treat that as a gap — report it in the UAT findings and flag it as a documentation issue.

## Decision Criteria

- **Approve** the `uat→main` promotion when all applicable test steps from the playbook pass and no console errors other than the documented viewer-role 403 allow-list are present
- **Request changes** when any test step fails — include specific failing steps, observed results vs. expected results, and failure screenshots
- **Block** if the plugin fails to load entirely — escalate to CTO as a deployment issue requiring immediate resolution
