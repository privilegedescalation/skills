#!/usr/bin/env bash
set -euo pipefail

# CI Health Check Script
# Scans all privilegedescalation repos for recent CI failures and reports issues

REPOS=(
  ".github"
  "infra"
  "org"
  "headlamp-rook-plugin"
  "headlamp-sealed-secrets-plugin"
  "headlamp-polaris-plugin"
  "headlamp-tns-csi-plugin"
  "headlamp-kube-vip-plugin"
  "headlamp-argocd-plugin"
  "headlamp-intel-gpu-plugin"
  "headlamp-plugin-template"
  "plugins"
  "headlamp-agent-skills"
)

FAILED_RUNS=0
TOTAL_RUNS=0

echo "## CI Health Check Report"
echo ""
echo "Scanning ${#REPOS[@]} repos for recent CI failures..."
echo ""

for repo in "${REPOS[@]}"; do
  echo "### $repo"
  
  # Get last 5 runs
  runs=$(gh run list --repo "privilegedescalation/$repo" --limit 5 --json status,conclusion,name,headBranch,updatedAt 2>/dev/null || echo "[]")
  
  if [ "$runs" = "[]" ]; then
    echo "- No recent runs (may not have CI configured)"
    echo ""
    continue
  fi

  # Count failures
  failure_count=$(echo "$runs" | jq '[.[] | select(.conclusion == "failure")] | length')
  TOTAL_RUNS=$((TOTAL_RUNS + 5))
  FAILED_RUNS=$((FAILED_RUNS + failure_count))

  if [ "$failure_count" -gt 0 ]; then
    echo "- ⚠️  $failure_count recent failure(s)"
    echo "$runs" | jq -r '.[] | select(.conclusion == "failure") | "  - \(.name) on \(.headBranch) (\(.updatedAt))"'
  else
    echo "- ✅ All recent runs passing"
  fi
  echo ""
done

echo "## Summary"
echo ""
echo "- Total repos scanned: ${#REPOS[@]}"
echo "- Failed runs (last 5 per repo): $FAILED_RUNS"
echo "- Success rate: $(awk "BEGIN {printf \"%.1f\", (($TOTAL_RUNS - $FAILED_RUNS) / $TOTAL_RUNS) * 100}")%"
echo ""

if [ "$FAILED_RUNS" -gt 0 ]; then
  echo "## Action Required"
  echo ""
  echo "$FAILED_RUNS failed run(s) detected. Review failures above and file issues for code bugs or infra fixes."
  exit 1
else
  echo "✅ All systems healthy. No CI failures detected."
  exit 0
fi
