#!/bin/bash
set -e

echo "🚀 Starting AppProject sync check..."

REPO_DIR="argo-projects"
NAMESPACE="argocd"

echo "📂 Current directory:"
pwd
echo "📂 Repo contents:"
ls -R

echo "📂 Reading project names from repo..."

repo_projects=""

for file in $REPO_DIR/*.yaml; do
  [ -f "$file" ] || continue

  echo "Processing $file"

  name=$(awk '/^metadata:/ {flag=1} flag && /name:/ {print $2; exit}' "$file")

  if [ -n "$name" ]; then
    repo_projects="$repo_projects $name"
  fi
done

repo_projects=$(echo "$repo_projects" | xargs)

echo "Repo projects:"
echo "$repo_projects"

# 🚨 SAFETY CHECK (prevents accidental deletion)
if [ -z "$repo_projects" ]; then
  echo "❌ No repo projects found — skipping deletion for safety"
  exit 0
fi

echo "📡 Fetching projects from cluster..."

cluster_projects=$(kubectl get appprojects -n $NAMESPACE -o jsonpath="{.items[*].metadata.name}")

echo "Cluster projects:"
echo "$cluster_projects"

echo "🔍 Comparing..."

for proj in $cluster_projects; do
  if echo "$repo_projects" | grep -qw "$proj"; then
    echo "✅ $proj exists in repo"
  else
    echo "❌ $proj NOT found in repo → deleting"
    kubectl delete appproject "$proj" -n $NAMESPACE
  fi
done

echo "✅ Cleanup completed"