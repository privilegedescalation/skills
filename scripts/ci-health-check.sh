#!/bin/bash
# CI Health Check Script
# Checks CI health across all privilegedescalation repos and reports failures

set -euo pipefail

# Configuration
ORG="privilegedescalation"
MAX_AGE_DAYS=30
CRITICAL_THRESHOLD=3  # Number of consecutive failures to consider critical

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Repos to monitor
REPOS=(
  "org"
  "infra"
  "headlamp-sealed-secrets-plugin"
  "headlamp-rook-plugin"
  "headlamp-intel-gpu-plugin"
  "headlamp-kube-vip-plugin"
  "headlamp-tns-csi-plugin"
  "headlamp-argocd-plugin"
  "headlamp-polaris-plugin"
)

echo "=== CI Health Check for $ORG ==="
echo "Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo ""

# Track issues
FAILURES=()
STALE_REPOS=()
NO_CI_REPOS=()

for repo in "${REPOS[@]}"; do
  echo "Checking $repo..."

  # Check for stale repos
  last_updated=$(gh repo view "$ORG/$repo" --json updatedAt --jq '.updatedAt' 2>/dev/null || echo "unknown")
  if [[ "$last_updated" != "unknown" ]]; then
    last_updated_date=$(date -d "$last_updated" +%s 2>/dev/null || echo "0")
    cutoff_date=$(date -d "$MAX_AGE_DAYS days ago" +%s)
    if [[ "$last_updated_date" -lt "$cutoff_date" ]]; then
      STALE_REPOS+=("$repo (last updated: $last_updated)")
      echo -e "  ${YELLOW}⚠ Stale repo${NC}"
    fi
  fi

  # Check for CI workflows
  workflow_count=$(gh api repos/"$ORG/$repo"/actions/workflows 2>/dev/null | jq -r '.total_count' || echo "0")
  if [[ "$workflow_count" -eq 0 ]]; then
    NO_CI_REPOS+=("$repo")
    echo -e "  ${YELLOW}⚠ No CI workflows configured${NC}"
    continue
  fi

  # Check recent CI runs (exclude approval gates)
  recent_failures=$(gh run list --repo "$ORG/$repo" --limit 10 \
    --json status,conclusion,name \
    | jq -r '.[] | select(.conclusion == "failure") | select(.name | contains("CI") or contains("E2E") or contains("ci") or contains("e2e")) | .conclusion' \
    | wc -l)

  if [[ "$recent_failures" -ge "$CRITICAL_THRESHOLD" ]]; then
    FAILURES+=("$repo: $recent_failures recent CI/E2E failures")
    echo -e "  ${RED}✗ $recent_failures recent CI/E2E failures${NC}"
  else
    echo -e "  ${GREEN}✓ CI healthy${NC}"
  fi
done

# Summary
echo ""
echo "=== Summary ==="

if [[ ${#FAILURES[@]} -eq 0 && ${#STALE_REPOS[@]} -eq 0 && ${#NO_CI_REPOS[@]} -eq 0 ]]; then
  echo -e "${GREEN}All systems healthy!${NC}"
  exit 0
else
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo -e "${RED}CI Failures:${NC}"
    for failure in "${FAILURES[@]}"; do
      echo "  - $failure"
    done
  fi

  if [[ ${#STALE_REPOS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Stale Repos (no updates in $MAX_AGE_DAYS+ days):${NC}"
    for stale in "${STALE_REPOS[@]}"; do
      echo "  - $stale"
    done
  fi

  if [[ ${#NO_CI_REPOS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Repos without CI:${NC}"
    for no_ci in "${NO_CI_REPOS[@]}"; do
      echo "  - $no_ci"
    done
  fi

  exit 1
fi
