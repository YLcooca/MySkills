#!/bin/bash
# Query and diff multiple Gerrit changes from a comma-separated changelist
# Usage: gerrit_changelist.sh <change_numbers> [--stat-only] [--diff]
#
# <change_numbers>: comma-separated list, e.g. "220454,224450,224762"
#
# Modes:
#   (default)    Show metadata and file list for each change (batch SSH query)
#   --stat-only  Show metadata + diff stat for each change
#   --diff       Show metadata + full diff for each change

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GERRIT_HOST="${GERRIT_HOST:-gerrit.evad.mioffice.cn}"
GERRIT_PORT="${GERRIT_PORT:-29418}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <change_numbers> [--stat-only] [--diff]"
  echo "  e.g. $0 \"220454,224450,224762\""
  echo "       $0 \"220454,224450,224762\" --stat-only"
  echo "       $0 \"220454,224450,224762\" --diff"
  exit 1
fi

CHANGE_LIST="$1"
shift

MODE="query"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stat-only) MODE="stat" ;;
    --diff) MODE="diff" ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

# Split comma-separated list into array
IFS=',' read -ra CHANGES <<< "$CHANGE_LIST"

TOTAL=${#CHANGES[@]}
echo "=== Changelist: $TOTAL changes ==="
echo ""

FAILED_CHANGES=()

if [ "$MODE" = "query" ]; then
  # Batch mode: single SSH query for all changes at once (much faster than N queries)
  QUERY_PARTS=()
  for CHANGE_NUM in "${CHANGES[@]}"; do
    CHANGE_NUM=$(echo "$CHANGE_NUM" | tr -d ' ')
    [ -z "$CHANGE_NUM" ] && continue
    QUERY_PARTS+=("change:$CHANGE_NUM")
  done

  # Join with OR for batch query
  OR_QUERY=""
  for part in "${QUERY_PARTS[@]}"; do
    if [ -n "$OR_QUERY" ]; then
      OR_QUERY="$OR_QUERY OR $part"
    else
      OR_QUERY="$part"
    fi
  done
  OR_QUERY="($OR_QUERY)"

  RAW_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query \
    --commit-message --current-patch-set --files --format=JSON \
    "$OR_QUERY" 2>/dev/null) || {
    echo "ERROR: SSH query failed"
    exit 1
  }

  echo "$RAW_OUTPUT" | python3 -c "
import sys, json

lines = sys.stdin.read().strip().split('\n')
idx = 0
for line in lines:
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        continue
    # Skip the stats line
    if 'rowCount' in data:
        continue
    idx += 1
    print('==========================================')
    print(f'[{idx}/$TOTAL] Change #{data.get(\"number\", \"?\")}')
    print('==========================================')
    ps = data.get('currentPatchSet', {})
    print(f\"Project:  {data['project']}\")
    print(f\"Branch:   {data['branch']}\")
    print(f\"Subject:  {data['subject']}\")
    print(f\"Status:   {data['status']}\")
    print(f\"Owner:    {data['owner']['name']}\")
    print(f\"URL:      {data['url']}\")
    print(f\"Patchset: {ps.get('number', '?')}\")
    files = [f for f in ps.get('files', []) if f['file'] != '/COMMIT_MSG']
    print(f'Files ({len(files)}):')
    for f in files:
        print(f\"  {f['type']:10} +{f['insertions']:<3}/-{f['deletions']:<3}  {f['file']}\")
    print()

if idx == 0:
    print('No changes found.')
"
else
  # stat/diff modes: must fetch each change individually (needs git fetch)
  for i in "${!CHANGES[@]}"; do
    CHANGE_NUM=$(echo "${CHANGES[$i]}" | tr -d ' ')
    if [ -z "$CHANGE_NUM" ]; then
      continue
    fi

    IDX=$((i + 1))
    echo "=========================================="
    echo "[$IDX/$TOTAL] Change #$CHANGE_NUM"
    echo "=========================================="

    case "$MODE" in
      stat)
        bash "$SCRIPT_DIR/gerrit_diff.sh" "$CHANGE_NUM" --stat-only 2>&1 || FAILED_CHANGES+=("$CHANGE_NUM")
        ;;
      diff)
        bash "$SCRIPT_DIR/gerrit_diff.sh" "$CHANGE_NUM" 2>&1 || FAILED_CHANGES+=("$CHANGE_NUM")
        ;;
    esac

    echo ""
  done
fi

echo "=========================================="
echo "Summary: $TOTAL changes processed"
if [ ${#FAILED_CHANGES[@]} -gt 0 ]; then
  echo "Failed: ${FAILED_CHANGES[*]}"
fi
