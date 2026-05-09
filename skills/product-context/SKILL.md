---
name: product-context
description: >
  Product context for Privileged Escalation. Covers current plugin portfolio,
  target users, competitive landscape, plugin evaluation framework, and feature
  spec template.
---

# Product Context

Load this section when triaging feature requests, evaluating new plugin proposals, or writing specs.

## Current plugin portfolio

| Plugin             | Repo                             | What it does                                    | Status |
| ------------------ | -------------------------------- | ----------------------------------------------- | ------ |
| **Polaris**        | `headlamp-polaris-plugin`        | Kubernetes best practice validation and scoring | Active |
| **Kube-VIP**       | `headlamp-kube-vip-plugin`       | Kube-VIP load balancer management               | Active |
| **Rook/Ceph**      | `headlamp-rook-plugin`           | Rook-Ceph storage cluster monitoring            | Active |
| **Sealed Secrets** | `headlamp-sealed-secrets-plugin` | Bitnami Sealed Secrets management               | Active |
| **Intel GPU**      | `headlamp-intel-gpu-plugin`      | Intel GPU device plugin monitoring              | Active |
| **TrueNAS CSI**    | `headlamp-tns-csi-plugin`        | TrueNAS SCALE CSI driver monitoring             | Active |

All plugins distributed via **ArtifactHub**, installed through Headlamp's native plugin installer only.

## Target users

**Primary: The Platform Engineer**

* Manages 1-50 Kubernetes clusters, mid-size company (100-2000 employees)
* Pain point: "I have 15 tools open to monitor my clusters. I want one dashboard that shows me everything."
* Very high tech comfort. Knows Kubernetes deeply. Will read your source code.
* Will adopt a plugin in 5 minutes if it solves a real problem. Will drop it in 5 seconds if it's buggy or doesn't add value over `kubectl`.

**Secondary: The DevOps Lead / SRE Manager**

* Manages a platform team, responsible for cluster health and reliability.
* Wants plugins that visualize what matters and surface problems proactively — NOT another monitoring tool.

**Anti-persona: The Application Developer**

App developers care about their deployments, not the cluster. Features like "show me my pod logs" are already in Headlamp core. Don't build for them.

## Scope

**In scope**

* Headlamp plugins that visualize and manage specific Kubernetes ecosystem tools
* Plugins that surface operational insights not available in Headlamp core
* Plugins for CNCF projects and widely-adopted K8s ecosystem tools
* ArtifactHub packaging and distribution

**Explicitly out of scope**

* Plugins that duplicate Headlamp core functionality
* Non-Kubernetes tools
* Hosted/SaaS versions of plugins
* Helm-based or sidecar-based plugin installation
* Custom Headlamp forks
* Monitoring/alerting backends (we visualize, we don't collect metrics)
* Multi-cluster management
* CLI tools

## Competitive landscape

| Competitor                       | Where PRI differs                                                                   |
| -------------------------------- | ----------------------------------------------------------------------------------- |
| **Headlamp core**                | We extend it, not compete. If a feature belongs in core, contribute upstream.       |
| **Lens**                         | Heavy, desktop-only, commercial. We make web-based, open source Headlamp better.    |
| **k9s**                          | Different modality (TUI vs web). Not competitive.                                   |
| **Komodor / Kubecost / Robusta** | Standalone products. Our plugins bring their insights INTO Headlamp. Complementary. |

PRI's moat: leading third-party Headlamp plugin developer. Plugins are free, open source, on ArtifactHub.

## Plugin evaluation framework

1. **Is there a widely-adopted K8s ecosystem tool that lacks Headlamp visibility?**
   * Fewer than 1,000 GitHub stars or in alpha → too early. Close with "revisit when more mature."
   * Already has a Headlamp plugin → duplicate. Close.
2. **Does the plugin add value over `kubectl` + the tool's own CLI/UI?**
   * "It shows the same thing but in Headlamp" → weak value prop. Good plugins correlate data, surface problems proactively, simplify complex operations.
3. **Can Gandalf build and maintain it?**
   * One engineer can maintain ~6-8 plugins at current complexity. We're at 6 now. New plugins mean either dropping an existing one or hiring.
4. **Is it installable via ArtifactHub without extras?**
   * Plugin requires CRDs/RBAC/cluster resources installed separately → degraded experience.
   * Unacceptable: plugin requires its own operator or sidecar.

**Priority tiers**

* **P0**: Bugs in existing plugins that break functionality or produce incorrect data
* **P1**: Enhancements to existing plugins users are requesting
* **P2**: New plugins for high-value K8s tools with clear user demand
* **P3**: Speculative plugins, cross-plugin features, UX experiments

## Feature spec template

```markdown
## Problem
What operational visibility or capability is missing? Who needs it? What do they do today instead?

## Proposed Solution
What should the plugin show or enable that isn't available today?

## Acceptance Criteria
- [ ] Plugin displays...
- [ ] User can...
- [ ] Data is accurate when compared to `kubectl` / native CLI output
- [ ] Works with [tool name] version X.Y+
- [ ] Installable via ArtifactHub without additional cluster-level setup
- [ ] Has unit tests covering core display logic

## Out of Scope for This Issue
## Dependencies
What must exist in the cluster for this plugin to work? (CRDs, operators, RBAC)

## Priority
P0/P1/P2/P3 with one-sentence justification.
```
