#!/bin/bash
# Query Gerrit change info via SSH API
# Usage: gerrit_query.sh <change_number> [--files] [--comments] [--summary]
# Returns JSON with change metadata, commit message, and optionally file list
# --summary: Output human-readable formatted summary instead of raw JSON (saves tokens)

set -euo pipefail

GERRIT_HOST="${GERRIT_HOST:-gerrit.evad.mioffice.cn}"
GERRIT_PORT="${GERRIT_PORT:-29418}"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <change_number> [--files] [--comments] [--summary]"
  echo "  e.g. $0 234293"
  echo "       $0 234293 --files"
  echo "       $0 234293 --summary        (formatted output, saves tokens)"
  echo "       $0 234293 --files --summary (formatted output with file list)"
  exit 1
fi

CHANGE_NUMBER="$1"
shift

EXTRA_FLAGS="--commit-message --current-patch-set"
SUMMARY=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --files) EXTRA_FLAGS="$EXTRA_FLAGS --files" ;;
    --comments) EXTRA_FLAGS="$EXTRA_FLAGS --comments" ;;
    --dependencies) EXTRA_FLAGS="$EXTRA_FLAGS --dependencies" ;;
    --all-approvals) EXTRA_FLAGS="$EXTRA_FLAGS --all-approvals" ;;
    --summary) SUMMARY=true ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
  shift
done

RAW_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query $EXTRA_FLAGS --format=JSON "change:$CHANGE_NUMBER")

if [ "$SUMMARY" = true ]; then
  echo "$RAW_OUTPUT" | python3 -c "
import sys, json

lines = sys.stdin.read().strip().split('\n')
if len(lines) < 2:
    print('ERROR: No results returned')
    sys.exit(1)

stats = json.loads(lines[-1])
if stats.get('rowCount', 0) == 0:
    print('ERROR: Change not found')
    sys.exit(1)

d = json.loads(lines[0])
ps = d.get('currentPatchSet', {})

print(f\"Project:  {d['project']}\")
print(f\"Branch:   {d['branch']}\")
print(f\"Subject:  {d['subject']}\")
print(f\"Status:   {d['status']}\")
print(f\"Owner:    {d['owner']['name']}\")
print(f\"URL:      {d['url']}\")
print(f\"Patchset: {ps.get('number', '?')}\")
msg = d.get('commitMessage', '')
if msg:
    print(f\"Commit Message:\")
    for line in msg.strip().split('\n'):
        print(f\"  {line}\")

files = [f for f in ps.get('files', []) if f['file'] != '/COMMIT_MSG']
if files:
    print(f\"Files ({len(files)}):\")
    for f in files:
        print(f\"  {f['type']:10} +{f['insertions']:<3}/-{f['deletions']:<3}  {f['file']}\")
"
else
  echo "$RAW_OUTPUT"
fi
