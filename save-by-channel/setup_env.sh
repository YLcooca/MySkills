#!/usr/bin/env bash
#
# 环境检查与安装脚本
# 用途：检查并安装 uv、创建 venv、安装 ad-cloud-sdk 依赖
# 用法：bash setup_env.sh
#
set -euo pipefail

WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$WORK_DIR/.venv"
PYTHON="$VENV_DIR/bin/python"
PIP="$VENV_DIR/bin/python -m pip"
LOG_DIR="$WORK_DIR/ad_cloud/logs"
SDK_SPEC='ad-cloud-sdk[adrn]==0.0.2+global.dev202603191132'
PIP_INDEX='https://pkgs.d.xiaomi.net/artifactory/api/pypi/pypi-virtual/simple'

# ── 颜色 ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
fail() { echo -e "${RED}❌ $*${NC}"; exit 1; }

echo "──────────────────────────────────────────"
echo "  环境检查 & 安装"
echo "──────────────────────────────────────────"
echo "  工作目录: $WORK_DIR"
echo "──────────────────────────────────────────"

# ── Step 1: 检查/安装 uv ─────────────────────────────────────────────────
echo ""
echo "[1/4] 检查 uv ..."
if command -v uv &>/dev/null; then
    ok "uv 已安装: $(uv --version)"
else
    echo "  正在安装 uv ..."
    pip install uv \
        --index-url "$PIP_INDEX" \
        --trusted-host pkgs.d.xiaomi.net
    ok "uv 安装完成: $(uv --version)"
fi

# ── Step 2: 创建虚拟环境 ─────────────────────────────────────────────────
echo ""
echo "[2/4] 检查虚拟环境 ..."
if [ -f "$PYTHON" ]; then
    ok "venv 已存在: $($PYTHON --version 2>&1)"
else
    echo "  正在创建 Python 3.9 虚拟环境 ..."
    cd "$WORK_DIR"
    uv venv .venv --python 3.9
    ok "venv 创建成功: $($PYTHON --version 2>&1)"
fi

# ── Step 3: 安装依赖 ─────────────────────────────────────────────────────
echo ""
echo "[3/4] 检查依赖 ..."

# 3.1 检查 pip 是否可用
if "$PYTHON" -m pip --version &>/dev/null; then
    ok "pip 已安装: $($PYTHON -m pip --version 2>&1 | head -1)"
else
    echo "  正在安装 pip ..."
    uv pip install --python "$PYTHON" pip \
        --index-url "$PIP_INDEX" \
        --trusted-host pkgs.d.xiaomi.net
    ok "pip 安装完成: $($PYTHON -m pip --version 2>&1 | head -1)"
fi

# 3.2 检查 ad-cloud-sdk 是否已安装
if "$PYTHON" -m pip show ad-cloud-sdk &>/dev/null; then
    _sdk_version=$("$PYTHON" -m pip show ad-cloud-sdk 2>/dev/null | grep "^Version:" | awk '{print $2}')
    ok "ad-cloud-sdk 已安装: ${_sdk_version}"
else
    echo "  正在安装 ad-cloud-sdk（可能需要 5~15 分钟）..."
    mkdir -p "$LOG_DIR"
    $PIP install \
        --index-url "$PIP_INDEX" \
        --trusted-host pkgs.d.xiaomi.net \
        "$SDK_SPEC"
    ok "ad-cloud-sdk 安装完成"
fi

# ── Step 4: 验证 ─────────────────────────────────────────────────────────
echo ""
echo "[4/4] 最终验证 ..."

if "$PYTHON" -m pip show ad-cloud-sdk &>/dev/null; then
    ok "环境验证通过"
else
    warn "ad-cloud-sdk 未安装"
fi

echo ""
echo "──────────────────────────────────────────"
echo "  环境就绪"
echo "──────────────────────────────────────────"
