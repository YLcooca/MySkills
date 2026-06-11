#!/bin/bash
# Query Gerrit change comments via REST API
# Usage: gerrit_comments.sh <change_number> [--file <path>] [--robot] [--summary]
#        gerrit_comments.sh --topic <topic_name> [--robot] [--summary]
#
# This script fetches review comments from Gerrit REST API.
# Supports:
#   - All comments on a change
#   - File-specific comments
#   - Robot comments (CI results)
#   - Topic mode (all comments in a topic)
#   - Summary mode (formatted, saves tokens)

set -euo pipefail

GERRIT_HOST="${GERRIT_HOST:-gerrit.evad.mioffice.cn}"
GERRIT_PORT="${GERRIT_PORT:-29418}"
GERRIT_URL="https://${GERRIT_HOST}"

ROBOT_ONLY=false
SPECIFIC_FILE=""
SUMMARY=false
TOPIC_MODE=false
TOPIC_NAME=""

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <change_number> [--file <path>] [--robot] [--summary]"
  echo "       $0 --topic <topic_name> [--robot] [--summary]"
  echo ""
  echo "Options:"
  echo "  --file <path>  Show comments for specific file only"
  echo "  --robot        Show robot/CI comments only"
  echo "  --summary      Formatted output (saves tokens)"
  echo "  --topic        Query all changes in a topic"
  echo ""
  echo "Examples:"
  echo "  $0 234293                    # All comments"
  echo "  $0 234293 --summary          # Formatted output"
  echo "  $0 234293 --file src/main.cc # Comments for specific file"
  echo "  $0 234293 --robot            # CI/robot comments only"
  echo "  $0 --topic my-topic          # All comments in topic"
  echo "  $0 --topic my-topic --summary # Formatted topic comments"
  exit 1
fi

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --topic)
      TOPIC_MODE=true
      shift
      TOPIC_NAME="$1"
      ;;
    --file)
      shift
      SPECIFIC_FILE="$1"
      ;;
    --robot) ROBOT_ONLY=true ;;
    --summary) SUMMARY=true ;;
    -*)
      echo "Unknown flag: $1"
      exit 1
      ;;
    *)
      if [ -z "$TOPIC_MODE" ] || [ "$TOPIC_MODE" = "false" ]; then
        CHANGE_NUMBER="$1"
      fi
      ;;
  esac
  shift
done

# Function to fetch comments for a single change
fetch_comments() {
  local change_id="$1"
  local api_endpoint
  
  if [ "$ROBOT_ONLY" = true ]; then
    api_endpoint="changes/${change_id}/revisions/current/robotscomments"
  else
    api_endpoint="changes/${change_id}/comments"
  fi
  
  curl -s --netrc --max-time 30 "${GERRIT_URL}/${api_endpoint}" | tail -c +5
}

# Function to format comments for a single change
format_change_comments() {
  local change_id="$1"
  local raw_json="$2"
  
  if [ "$SUMMARY" = true ]; then
    echo "$raw_json" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
except:
    print(f'ERROR: Failed to parse comments for change ${change_id}')
    sys.exit(1)

specific_file = '${SPECIFIC_FILE}'

# Filter by file if specified
if specific_file:
    data = {k: v for k, v in data.items() if k == specific_file}
    if not data:
        print(f'No comments found for file {specific_file}')
        sys.exit(0)

total = sum(len(v) for v in data.values())
if total == 0:
    print(f'No comments for change ${change_id}')
    sys.exit(0)

print(f'=== Change #${change_id} ({total} comments) ===')
print()

for filepath, comments in sorted(data.items()):
    print(f'File: {filepath}')
    print('-' * 60)
    for c in comments:
        author = c.get('author', {}).get('name', 'Unknown')
        line = c.get('line', '?')
        msg = c.get('message', '').strip()
        ps = c.get('patch_set', '?')
        updated = c.get('updated', '')[:19]
        
        # Truncate long messages
        if len(msg) > 200:
            msg = msg[:200] + '...'
        
        print(f'  PS{ps} Line {line} | {author} ({updated})')
        for mline in msg.split('\n'):
            print(f'    {mline}')
        print()
    print()
"
  else
    echo "$raw_json" | python3 -m json.tool
  fi
}

# Topic mode: query all changes in topic
if [ "$TOPIC_MODE" = true ]; then
  if [ -z "$TOPIC_NAME" ]; then
    echo "ERROR: --topic requires a topic name"
    exit 1
  fi
  
  # Get all changes in topic
  QUERY_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query \
    --format=JSON "status:open topic:$TOPIC_NAME OR status:merged topic:$TOPIC_NAME" 2>/dev/null || true)
  
  # Also try with just topic: prefix
  if [ -z "$QUERY_OUTPUT" ] || echo "$QUERY_OUTPUT" | grep -q '"rowCount":0'; then
    QUERY_OUTPUT=$(ssh -p "$GERRIT_PORT" "$GERRIT_HOST" gerrit query \
      --format=JSON "topic:$TOPIC_NAME" 2>/dev/null || true)
  fi
  
  if [ -z "$QUERY_OUTPUT" ]; then
    echo "ERROR: No changes found for topic '$TOPIC_NAME'"
    exit 1
  fi
  
  # Extract change numbers
  CHANGE_NUMBERS=$(echo "$QUERY_OUTPUT" | python3 -c "
import sys, json
lines = sys.stdin.read().strip().split('\n')
changes = []
for line in lines[:-1]:  # Skip stats line
    try:
        d = json.loads(line)
        if 'number' in d:
            changes.append(str(d['number']))
    except:
        continue
print(' '.join(changes))
")
  
  if [ -z "$CHANGE_NUMBERS" ]; then
    echo "No changes found for topic '$TOPIC_NAME'"
    exit 0
  fi
  
  echo "=== Topic: $TOPIC_NAME ==="
  echo "Changes: $CHANGE_NUMBERS"
  echo ""
  
  # Fetch comments for each change
  TOTAL_COMMENTS=0
  for change in $CHANGE_NUMBERS; do
    RAW_OUTPUT=$(fetch_comments "$change")
    
    # Check if response is valid JSON
    if ! echo "$RAW_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
      echo "WARNING: Failed to fetch comments for change $change"
      continue
    fi
    
    # Check if empty
    COMMENT_COUNT=$(echo "$RAW_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(len(v) for v in d.values()))" 2>/dev/null || echo "0")
    
    if [ "$COMMENT_COUNT" != "0" ]; then
      TOTAL_COMMENTS=$((TOTAL_COMMENTS + COMMENT_COUNT))
      format_change_comments "$change" "$RAW_OUTPUT"
    fi
  done
  
  echo "=== Total: $TOTAL_COMMENTS comments across $(echo $CHANGE_NUMBERS | wc -w) changes ==="

# Single change mode
else
  if [ -z "${CHANGE_NUMBER:-}" ]; then
    echo "ERROR: No change number provided"
    exit 1
  fi
  
  RAW_OUTPUT=$(fetch_comments "$CHANGE_NUMBER")
  
  # Check if response is valid JSON
  if ! echo "$RAW_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "ERROR: Failed to fetch comments for change ${CHANGE_NUMBER}"
    echo "Raw response: ${RAW_OUTPUT:0:200}"
    exit 1
  fi
  
  # Check if empty
  COMMENT_COUNT=$(echo "$RAW_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(len(v) for v in d.values()))")
  if [ "$COMMENT_COUNT" = "0" ]; then
    echo "No comments found for change ${CHANGE_NUMBER}"
    exit 0
  fi
  
  format_change_comments "$CHANGE_NUMBER" "$RAW_OUTPUT"
fi
