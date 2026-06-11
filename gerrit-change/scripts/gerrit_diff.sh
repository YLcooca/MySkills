#!/bin/bash
# Fetch a Gerrit change and output its diff content
# Usage: gerrit_diff.sh <change_number> [--stat-only] [--file <path>]
#
# This script:
# 1. Queries Gerrit SSH for change metadata (project, ref, parent)
# 2. Creates a temp git repo, fetches the change ref
# 3. Outputs the diff (full or stat-only, or for a specific file)

set -euo pipefail

GERRIT_HOST="${GERRIT_HOST:-gerrit.evad.mioffice.cn}"
GERRIT_PORT="${GERRIT_PORT:-29418}"
GERRIT_SSH_URL="ssh://${GERRIT_HOST}:${GERRIT_PORT}"

STAT_ONLY=false
SPECIFIC_FILE=""
PS_FROM=""
PS_TO=""

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <change_number> [--stat-only] [--file <path>] [--ps <from>..<to>]"
  exit 1
fi

CHANGE_NUMBER="$1"
shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stat-only) STAT_ONLY=true ;;
    --file)
      shift
      SPECIFIC_FILE="$1"
      ;;
    --ps)
      shift
      PS_FROM="${1%..*}"
      PS_TO="${1#*..}"
      ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# Step 1: Query change info
QUERY_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query \
  --commit-message --current-patch-set --format=JSON "change:$CHANGE_NUMBER")

CHANGE_INFO=$(echo "$QUERY_OUTPUT" | head -1)

# Validate that the change exists
ROW_COUNT=$(echo "$QUERY_OUTPUT" | tail -1 | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('rowCount', 0))")
if [ "$ROW_COUNT" = "0" ]; then
  echo "ERROR: Change $CHANGE_NUMBER not found or you don't have permission to access it."
  exit 1
fi

# Extract metadata (parse once, use tab as delimiter)
IFS=$'\t' read -r PROJECT REF SUBJECT PATCHSET PARENT_COUNT < <(echo "$CHANGE_INFO" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['project'] + '\t' + data['currentPatchSet']['ref'] + '\t' + data['subject'] + '\t' +
      str(data['currentPatchSet']['number']) + '\t' + str(len(data['currentPatchSet']['parents'])))
")

echo "=== Change #${CHANGE_NUMBER} (Patchset ${PATCHSET}) ==="
echo "Project: $PROJECT"
echo "Subject: $SUBJECT"
echo "Ref: $REF"
echo ""

# Step 2: Fetch the change into a temp repo
WORK_DIR=$(mktemp -d "/tmp/gerrit-diff-XXXXXXXXXX")
trap "rm -rf '$WORK_DIR'" EXIT INT TERM

cd "$WORK_DIR"
git init -q

# Compute ref prefix: refs/changes/<last2>/<change>
CHANGE_SUFFIX=$(printf '%s' "$CHANGE_NUMBER" | tail -c 2)
REF_PREFIX="refs/changes/${CHANGE_SUFFIX}/${CHANGE_NUMBER}"

# Step 3: Output diff
if [ -n "$PS_FROM" ] && [ -n "$PS_TO" ]; then
  # Patchset-to-patchset diff
  echo "Patchset diff: ps${PS_FROM}..ps${PS_TO}"
  echo ""
  git fetch -q "${GERRIT_SSH_URL}/${PROJECT}" "${REF_PREFIX}/${PS_FROM}" 2>/dev/null && git tag ps_from FETCH_HEAD
  git fetch -q "${GERRIT_SSH_URL}/${PROJECT}" "${REF_PREFIX}/${PS_TO}" 2>/dev/null
  DIFF_RANGE="ps_from..FETCH_HEAD"
else
  git fetch -q "${GERRIT_SSH_URL}/${PROJECT}" "$REF" 2>/dev/null
  if [ "$PARENT_COUNT" -gt 1 ]; then
    DIFF_RANGE="FETCH_HEAD^1..FETCH_HEAD"
  else
    DIFF_RANGE="FETCH_HEAD~1..FETCH_HEAD"
  fi
fi

if [ "$STAT_ONLY" = true ]; then
  git diff --stat "$DIFF_RANGE" ${SPECIFIC_FILE:+-- "$SPECIFIC_FILE"}
else
  if [ -n "$SPECIFIC_FILE" ]; then
    git diff "$DIFF_RANGE" -- "$SPECIFIC_FILE"
  else
    git diff "$DIFF_RANGE"
  fi
fi
