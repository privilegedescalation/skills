---
name: uat
description: >
  Functional UAT procedures for Privileged Escalation Headlamp plugins. Concrete testing steps, pass/fail criteria, and artifact requirements for each plugin.
---

# UAT Procedures

## Purpose

This skill defines **functional User Acceptance Testing** for all Privileged Escalation Headlamp plugins. UAT validates that plugins work correctly in the deployed environment — by **loading plugins in a running Headlamp instance and exercising their features**, not by browsing GitHub or inspecting PR diffs.

## What UAT Is NOT

- Browsing GitHub PRs and taking screenshots of code diffs
- Checking CI status on GitHub
- Reading commit messages or PR descriptions
- Approving based on QA's review alone

If your test evidence is screenshots of GitHub pages, you are not performing UAT.

## UAT Environment

The UAT Headlamp instance runs in the `headlamp-uat` Kubernetes namespace. Navigate to the Headlamp UAT URL using your Playwright browser. The plugin under test must be deployed to UAT before testing.

## General Process

For every `uat→main` promotion:

1. Open the Headlamp UAT instance in the browser
2. Confirm the plugin appears in the sidebar or app bar
3. Run the plugin-specific test steps below
4. Capture screenshots of the **running plugin** at each verification step
5. Check the browser console for errors
6. Post a structured test report (see Artifacts section)

## Plugin Test Procedures

### headlamp-polaris-plugin — Kubernetes Best Practices

**Access:** Sidebar → Polaris section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the Polaris dashboard | Cluster score loads with a numeric value |
| 2 | Verify workload list populates | Shows deployments/pods with individual scores |
| 3 | Click into any workload | Detail view shows pass/fail/warning checks with descriptions |
| 4 | Cross-check one score against `kubectl` | Polaris CLI output matches plugin display |

**Pass:** Dashboard loads, shows real workload data, scores are non-zero, detail views navigate correctly.
**Fail:** Page errors, empty data when workloads exist, scores show 0/NaN, detail navigation broken.

### headlamp-sealed-secrets-plugin — Sealed Secrets Management

**Access:** Sidebar → Sealed Secrets section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the Sealed Secrets list | List view loads (may be empty if no secrets exist) |
| 2 | Check the create form | Create sealed secret form is accessible with expected fields |
| 3 | View an existing sealed secret | Detail view shows metadata, status, and namespace |
| 4 | Verify sealed secret status | Status reflects actual K8s state |

**Pass:** List loads, create form accessible, detail views work, status accurate.
**Fail:** Page errors, CRUD forms don't render, missing UI elements, status mismatch.

### headlamp-intel-gpu-plugin — Intel GPU Monitoring

**Access:** Sidebar → Intel GPU section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the GPU section | GPU device list or status page loads |
| 2 | Check node-level GPU info | Per-node GPU allocation is displayed |
| 3 | Verify device status | Device plugin status matches `kubectl describe node` GPU capacity |

**Pass:** Section loads, shows GPU device information or empty state if no Intel GPUs present, no console errors.
**Fail:** Page errors, data loading failures, broken rendering.

### headlamp-kube-vip-plugin — Load Balancer Management

**Access:** Sidebar → Kube-VIP section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the Kube-VIP section | Load balancer status view loads |
| 2 | Check VIP list | VIP addresses and their status are displayed |
| 3 | View configuration details | Configuration is accessible and readable |
| 4 | Verify against cluster state | VIP data matches `kubectl get svc` LoadBalancer entries |

**Pass:** Section loads, shows VIP data or empty state, navigation works.
**Fail:** Page errors, data not rendering, broken navigation.

### headlamp-tns-csi-plugin — TrueNAS CSI Monitoring

**Access:** Sidebar → TrueNAS CSI section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the TrueNAS CSI section | Volume list loads |
| 2 | Check PV/PVC list | Shows provisioned volumes with capacity and status |
| 3 | View volume details | Detail view shows storage class, capacity, access modes |
| 4 | Verify against cluster state | Volume data matches `kubectl get pv,pvc` output |

**Pass:** Section loads, shows CSI volumes/status, detail views work.
**Fail:** Page errors, empty state when volumes exist, broken detail views.

### headlamp-rook-plugin — Rook/Ceph Storage

**Access:** Sidebar → Rook/Ceph section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the Rook/Ceph dashboard | Cluster health overview loads |
| 2 | Check storage pools | Pool list shows capacity and utilization |
| 3 | Verify OSD status | OSD count and status displayed |
| 4 | Check placement groups | PG status summary is available |

**Pass:** Dashboard loads, shows cluster health, pool data renders correctly.
**Fail:** Page errors, cluster data missing, health indicators broken.

### headlamp-argocd-plugin — Argo CD Application Delivery

**Access:** Sidebar → Argo CD section

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | Navigate to the Argo CD application list | Application list loads with sync status |
| 2 | Check sync indicators | Each app shows Synced/OutOfSync/Unknown status |
| 3 | Click into an application | Detail view shows resources, sync history, health |
| 4 | Verify health status | Health icons (Healthy/Degraded/Progressing) are correct |
| 5 | Cross-check against `argocd app list` | Status matches CLI output |

**Pass:** App list loads, sync/health status visible, detail views work, data matches CLI.
**Fail:** Page errors, empty list when apps exist, status missing, broken navigation.

## UAT Artifacts

For each plugin tested, the UAT report must include:

1. **Screenshots** of the plugin running in Headlamp — sidebar entry visible, main view loaded, at least one detail view
2. **Test checklist** — each step from the plugin table above marked pass/fail
3. **Console errors** — any browser console errors observed (attach screenshot if present)
4. **Environment** — Headlamp version, plugin version, browser used

## Decision Criteria

- **Approve** the `uat→main` PR when all applicable test steps pass
- **Request changes** with specific failing steps and failure screenshots
- **Block** if the plugin fails to load entirely — escalate to CTO as a deployment issue
