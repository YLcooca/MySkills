#!/bin/bash
# Query all changes in a Gerrit topic
# Usage: gerrit_topic.sh <topic_name> [--status open|all|merged] [--summary]
#
# --summary: Output human-readable table instead of raw JSON (saves tokens)
# Default (no --summary): Returns JSON lines for each change in the topic

set -euo pipefail

GERRIT_HOST="${GERRIT_HOST:-gerrit.evad.mioffice.cn}"
GERRIT_PORT="${GERRIT_PORT:-29418}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <topic_name> [--status open|all|merged] [--summary]"
  echo "  e.g. $0 my-topic"
  echo "       $0 my-topic --status all"
  echo "       $0 my-topic --summary"
  exit 1
fi

TOPIC_NAME="$1"
shift

STATUS_FILTER="status:open"
SUMMARY=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --status)
      shift
      case "$1" in
        open) STATUS_FILTER="status:open" ;;
        all) STATUS_FILTER="" ;;
        merged) STATUS_FILTER="status:merged" ;;
        *) echo "Unknown status: $1 (use open|all|merged)"; exit 1 ;;
      esac
      ;;
    --summary) SUMMARY=true ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

QUERY="topic:$TOPIC_NAME"
if [ -n "$STATUS_FILTER" ]; then
  QUERY="$STATUS_FILTER $QUERY"
fi

RAW_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query \
  --commit-message --current-patch-set --files --format=JSON \
  "$QUERY")

if [ "$SUMMARY" = true ]; then
  echo "$RAW_OUTPUT" | python3 -c "
import sys, json

lines = sys.stdin.read().strip().split('\n')
if len(lines) < 1:
    print('ERROR: No results returned')
    sys.exit(1)

# Last line is always the stats line
stats = json.loads(lines[-1])
changes = []
for line in lines[:-1]:
    try:
        changes.append(json.loads(line))
    except json.JSONDecodeError:
        continue

count = stats.get('rowCount', 0)
print(f'=== Topic: $TOPIC_NAME ({count} changes) ===')
print()

if count == 0:
    print('No changes found.')
    sys.exit(0)

# Table header
print(f\"{'#Change':<10} {'Project':<35} {'Branch':<15} {'Status':<10} {'PS':<4} {'Files':<6} Subject\")
print('-' * 120)

for d in changes:
    ps = d.get('currentPatchSet', {})
    files = [f for f in ps.get('files', []) if f['file'] != '/COMMIT_MSG']
    num = str(d.get('number', '?'))
    proj = d['project']
    if len(proj) > 33:
        proj = '...' + proj[-30:]
    print(f\"{num:<10} {proj:<35} {d['branch']:<15} {d['status']:<10} {ps.get('number','?'):<4} {len(files):<6} {d['subject']}\")
"
else
  echo "$RAW_OUTPUT"
fi
