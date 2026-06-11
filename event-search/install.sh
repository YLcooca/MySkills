#!/usr/bin/env bash
#
# 将 event-search skill 安装到 ~/.claude/skills/
# 用法: bash install.sh
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$HOME/.claude/skills/event-search"

echo "安装 event-search skill ..."
echo "  源目录: $SRC_DIR"
echo "  目标目录: $DEST_DIR"

mkdir -p "$DEST_DIR"

for f in event_search.py setup_env.sh SKILL.md; do
    if [ -f "$SRC_DIR/$f" ]; then
        cp "$SRC_DIR/$f" "$DEST_DIR/$f"
        echo "  ✅ $f"
    else
        echo "  ❌ $f 不存在"
    fi
done

chmod +x "$DEST_DIR/setup_env.sh"
echo ""
echo "安装完成: $DEST_DIR"
