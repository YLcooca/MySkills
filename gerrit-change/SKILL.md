---
name: gerrit-change
description: Query Gerrit changes for code review and debugging. Use this skill whenever the user mentions Gerrit change numbers, change URLs, Change-IDs, changelists, or topic names. Also trigger when they ask "what changed?", want to see diffs, debug recent cherry-picks, or investigate CI failures. Even if they don't explicitly say "Gerrit", use this skill when you see change numbers (like 234293), repo references, or any code review context. When in doubt about whether to use this skill, USE IT.
---

# Gerrit Change Query Skill

## How to extract change info from user input

- **Change URL**: Extract number from `https://gerrit.evad.mioffice.cn/c/<project>/+/<number>`
- **Patchset range URL**: `https://gerrit.evad.mioffice.cn/c/<project>/+/<number>/<from>..<to>` → use `gerrit_diff.sh <number> --ps <from>..<to>`
- **Plain number**: Use directly (234293)
- **Change-Id**: Hash starting with `I` (If31f77...) - works with query API
- **Changelist**: Comma-separated (220454,224450,224762) - use `gerrit_changelist.sh`
- **Topic**: String identifier (username-topic-name) or URL `gerrit.evad.mioffice.cn/q/topic:"<topic>"` → `gerrit_topic.sh`

Gerrit server: `gerrit.evad.mioffice.cn` (SSH port 29418)

## Core operations

The skill provides 5 scripts in `scripts/` directory:

1. **`gerrit_query.sh <change> [--files] [--summary]`** - Fast SSH query for metadata + file list (no git fetch). Use `--summary` to get formatted output instead of raw JSON.
2. **`gerrit_diff.sh <change> [--stat-only|--file <path>|--ps <from>..<to>]`** - Fetch change via git and generate diff; `--ps` diffs between two patchsets
3. **`gerrit_changelist.sh "<change1,change2,...>" [--stat-only|--diff]`** - Batch changes metadata query. Add `--stat-only` or `--diff` for diffs.
4. **`gerrit_topic.sh <topic> [--status open|all|merged] [--summary]`** - Query all changes in a topic. Always use `--summary` for table view.
5. **`gerrit_comments.sh <change> [--file <path>] [--robot] [--summary]`** - Query review comments via REST API. `--robot` for CI comments only, `--file` for specific file comments. Use `--topic <name>` to query all comments in a topic.

### Decision tree for token efficiency

**Why this order?** `gerrit_query.sh` is a pure SSH call (~1s, no git fetch). `gerrit_diff.sh` creates a temp repo and fetches code (5-30s, large output). Always start with the lightweight query to understand scope, then fetch specific diffs as needed.

- **User asks "what changed?"** → `gerrit_query.sh <change> --files --summary` (fast, formatted, shows file list + metadata)
- **Need actual code diff?** → Use `gerrit_diff.sh <change> --stat-only` first (overview), then `--file <path>` for specific files
- **Patchset-to-patchset diff?** → `gerrit_diff.sh <change> --ps 2..3` (e.g. from URL `.../234293/2..3`)
- **Multiple changes?** → Use `gerrit_changelist.sh` with default mode (batch metadata query, single SSH call) first, then `--stat-only` if needed
- **Topic?** → Use `gerrit_topic.sh <topic> --summary`, then drill into individual changes if needed
- **Need comments?** → `gerrit_comments.sh <change> --summary` (review comments) or `--robot` (CI comments)
- **All comments in topic?** → `gerrit_comments.sh --topic <topic> --summary`

### Output modes

- **`--summary`** (recommended): Formatted text output containing project, branch, subject, status, owner, URL, patchset number, commit message, file list. Saves 90%+ tokens.
- **Raw JSON** (default without `--summary`): Full Gerrit JSON. Use when you need fields not in summary (CI labels/approvals, reviewers, timestamps, topic, Change-Id, etc.)

## Workflow guidelines

**Token-efficient querying strategy:**
1. Always use `--summary` flag for formatted output (saves 90%+ tokens vs raw JSON) for most scenarios
2. Start with `--files` (fast SSH query, no git fetch) to understand scope
3. For large changes: use `--stat-only` before fetching full diff
4. For specific investigation: use `--file <path>` to get targeted diffs
5. For changelists/topics: get metadata first, then drill into specific changes
6. When reviewing the detailed diff of a file in a change, prioritize fetching the full diff in the file entirety, rather than truncating it using commands such as head or tail.

**When presenting results:**
- Always include change URL and subject line
- Summarize file changes (added/modified/deleted counts)
- For diffs: focus on relevant sections, explain context
- For large outputs: summarize patterns rather than dumping everything

### Error handling

Do NOT access user's SSH config or other sensitive files. When errors occur, provide the following templated guidance:

- **SSH timeout / Connection refused** → 提示用户: "请检查 VPN 是否连接，以及 SSH 配置中是否已配置 `Host gerrit.evad.mioffice.cn`（端口 29418）"
- **"Change not found"** → 提示用户确认 change 号是否正确；如用户给的是 `I` 开头的 Change-Id，尝试直接用该 ID 查询
- **Permission denied** → 提示用户: "该 change 可能属于受限项目，请确认是否有访问权限"
- **Empty diff output** → 可能是 merge commit，用 `gerrit_query.sh` 确认 parent 数量

**Technical notes:**
- Uses user's SSH config (`~/.ssh/config`) - no additional auth needed
- Scripts require: `python3`, `jq`, `git`
- Environment variables: `GERRIT_HOST`, `GERRIT_PORT` (optional overrides)
