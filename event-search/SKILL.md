---
name: event-search
description: 查询自动驾驶事件数据，支持通过 JIRA ID、ADRN、车辆、时间范围、事件类型等多种方式查询事件、行程、通道、录制文件等信息。适用场景：用户说"查询事件"、"搜索事件"、"查找 JIRA"、"查询 ADRN"、"事件搜索"、"event search"、"按车辆查事件"、"查量产/路测数据"等。负责配置本地 Python 环境、参考原子能力函数、生成满足用户意图的代码并执行。
---

# Event Search 事件查询 Skill

你的任务是：**理解用户意图 → 配置环境 → 参考原子能力 → 生成代码 → 执行并返回结果**。

`event_search.py` 是**原子能力参考库**，不是可直接执行的脚本。你需要阅读其中的函数签名和逻辑，理解 AD-CLOUD-SDK 的能力边界，然后**根据用户意图生成对应的代码**，保存到用户工作目录并执行。

按以下阶段顺序执行。

**第一步必须是环境检查（阶段 -1），绝对不能跳过或后置。**

## 原子能力函数速查

| 函数 | 说明 |
|---|---|
| `query_by_jira_id(jira_id)` | 通过 JIRA ID 查询事件（先量产再路测） |
| `query_by_adrn(adrn)` | 通过 ADRN 查询索引、通道、录制文件 |
| `query_prod_events(query_param)` | 查询量产事件 ID 列表（返回 List[str]） |
| `count_prod_event(query_param)` | 查询量产事件总数（返回 int） |
| `query_test_events(query_param)` | 查询路测事件 ID 列表（返回 List[str]） |
| `count_test_event(query_param)` | 查询路测事件总数（返回 int） |
| `query_event_detail(event_id, env)` | 查询事件详情（ADRN/Session/Drive/Detail） |
| `query_event_detail_by_jira(jira_id)` | 通过 JIRA ID 查事件详情 |
| `query_detail(event_id, env)` | 查询事件完整详情（EventData） |
| `query_detail_with_loc(event_id, env)` | 查询事件详情（含位置信息） |
| `download_event(event_id, path, type, env)` | 下载事件文件（MCAP/LOG/RADAR） |
| `download_by_adrn(adrn, path)` | 根据 ADRN 下载原始数据 |
| `query_available_tags()` | 查询可用标签列表 |

参数详情见 `event_search.py` 各函数 docstring。

---

---

## ⚠️ 强制规则（必须严格遵守）

1. **虚拟环境和依赖必须安装在用户的当前工作目录（`$CWD`），禁止安装在 SKILL 目录。**
   - 虚拟环境路径：`$CWD/.venv`
   - 工作目录：`$CWD`

2. **所有 Python 代码必须使用 `$CWD/.venv/bin/python` 执行，禁止使用系统 Python 或其他虚拟环境。**
   - 执行命令格式：`cd "$CWD" && .venv/bin/python <生成的脚本>.py`
   - 禁止 `source .venv/bin/activate` 后直接调 `python`，必须用完整路径 `.venv/bin/python`

3. **所有 pip 操作必须使用 `$CWD/.venv/bin/python -m pip`，禁止使用系统 pip。**
   - 安装命令格式：`$CWD/.venv/bin/python -m pip install <package>`
   - 禁止直接调 `pip install`

4. **`event_search.py` 是原子能力参考库，禁止直接执行它。**
   - 你需要阅读 `event_search.py` 中的函数，理解每个函数的参数、返回值、调用方式
   - 根据用户意图，**生成新的 Python 脚本**保存到 `$CWD` 下执行
   - 生成的脚本应只包含用户需要的功能，不要引入无关函数

5. **禁止使用 `rm`、`rmdir`、`unlink` 等删除命令删除用户的文件或目录。**

6. **用户参数必须由用户明确提供，禁止使用硬编码示例值直接执行。**

7. **禁止修改 ad-cloud-sdk 的源码（`.venv/lib/python*/site-packages/ad_cloud/` 下的文件）。**
   - 如果 SDK 能力不满足需求，应告知用户，由用户决定是否联系 SDK 维护者
   - 生成的脚本只能使用 SDK 公开的 API，不得 monkey-patch 或 hack SDK 内部实现

8. **Python 版本必须通过 AskUserQuestion 让用户选择，禁止自动选择。**
   - `setup_env.sh` 接收版本号作为参数：`bash setup_env.sh 3.9`
   - 禁止 `echo "1" | bash`、`yes | bash`、`printf "1\n" | bash` 等管道注入
   - 禁止跳过选择直接使用默认值

9. **时间范围查询必须拆分为不超过 1 天的分段，循环查询后合并结果。**
   - 单次查询时间跨度不得超过 1 天（86400000000000 纳秒）
   - 超过 1 天的范围，必须按 1 天切片循环调用，将所有结果合并返回
   - 例如查询 7 天数据，需拆分为 7 个 1 天分段分别查询

---

## 阶段 -1：环境检查（强制第一步）

在做任何操作之前，先确定用户当前工作目录并检查环境：

```bash
CWD="$(pwd)"
SKILL_DIR="$HOME/.claude/skills/event-search"
echo "=== 环境检查 ==="
echo "  工作目录: $CWD"
echo "  Skill 目录: $SKILL_DIR"
# 1. setup_env.sh（在 SKILL 目录中）
if [ -f "$SKILL_DIR/setup_env.sh" ]; then echo "✅ setup_env.sh 存在"; else echo "❌ setup_env.sh 不存在: $SKILL_DIR/setup_env.sh"; fi
# 2. event_search.py（原子能力参考，在 SKILL 目录中）
if [ -f "$SKILL_DIR/event_search.py" ]; then echo "✅ event_search.py 存在（原子能力参考）"; else echo "❌ event_search.py 不存在: $SKILL_DIR/event_search.py"; fi
# 3. 虚拟环境（在用户工作目录中）
if [ -f "$CWD/.venv/bin/python" ]; then echo "✅ 虚拟环境存在: $($CWD/.venv/bin/python --version 2>&1)"; else echo "❌ 虚拟环境不存在: $CWD/.venv"; fi
# 4. ad-cloud-sdk（在用户工作目录的 venv 中）
if [ -f "$CWD/.venv/bin/python" ] && "$CWD/.venv/bin/python" -c "import ad_cloud" 2>/dev/null; then echo "✅ ad-cloud-sdk 已安装"; else echo "❌ ad-cloud-sdk 未安装"; fi
echo "=== 检查完毕 ==="
```

根据检查结果决策：

| 情况 | 动作 |
|---|---|
| **全部 ✅**（SKILL 文件 + venv + SDK 都存在） | 向用户报告环境就绪，**跳过阶段 0~1**，直接进入**阶段 2** |
| **SKILL 文件存在，但 venv/SDK 缺失** | 进入**阶段 0 & 1** 修复环境 |
| **SKILL 文件缺失** | 告知用户 SKILL 文件不完整，请检查安装 |

---

## 阶段 0 & 1：环境准备

### Step 1: 选择 Python 版本

**必须使用 AskUserQuestion 让用户选择，禁止自动选择或管道注入。**

```
AskUserQuestion(
  header: "Python 版本",
  question: "请选择 Python 版本（uv 会自动下载）",
  options: [
    { label: "Python 3.9 (推荐)", description: "稳定性最佳" },
    { label: "Python 3.10", description: "较新版本" },
    { label: "Python 3.11", description: "较新版本" },
    { label: "Python 3.12", description: "最新稳定版" },
  ],
  multiSelect: false
)
```

提取用户选择的版本号（如 `3.9`），存为 `$PYTHON_VER`。

### Step 2: 安装环境

将 SKILL 目录中的 `setup_env.sh` 复制到用户工作目录，**将版本号作为参数传入**：

```bash
SKILL_DIR="$HOME/.claude/skills/event-search"
CWD="$(pwd)"
cp "$SKILL_DIR/setup_env.sh" "$CWD/setup_env.sh"
cd "$CWD" && bash setup_env.sh "$PYTHON_VER"
```

> ⚠️ **ad-cloud-sdk 安装过程可能耗时 5~15 分钟，必须持续等待，不得中断。**

> ⚠️ **ad-cloud-sdk 安装过程可能耗时 5~15 分钟，必须持续等待，不得中断。**
> 执行 Bash 工具时将 timeout 设置为 **1800000**（30 分钟）。

安装完成后验证：

```bash
CWD="$(pwd)"
"$CWD/.venv/bin/python" -c "import ad_cloud; print('✅ SDK 可用')"
```

---

## 阶段 2：获取用户凭证并设置必填环境变量

通过 `ad-cloud-mcp-oversea` MCP 的 `get_user_info` 获取凭证：

- 若成功，提取 `access_key`、`secret_key`、`username`、`cas_dept`
- 若 MCP 不可用，告知用户配置后重试

**以下 8 个环境变量是必填的，必须全部写入生成脚本的头部，在所有 import 之前设置：**

| 环境变量 | 值来源 | 说明 |
|---|---|---|
| `AD_CLOUD_DATASET_CALL_ENV` | 固定值 `"tjv1"` | SDK 调用环境 |
| `XIAOMI_IAM_ACCESS_KEY_ID` | MCP → `access_key` | IAM 认证 |
| `XIAOMI_IAM_SECRET_ACCESS_KEY` | MCP → `secret_key` | IAM 认证 |
| `AD_CLOUD_XIAOMI_DEPARTMENT` | MCP → `cas_dept` | 部门 |
| `XIAOMI_USERNAME` | MCP → `username` | 用户名 |
| `EVENT_TYPE` | 固定值 `"prod"` 或 `"test"` | 数据类型 |
| `AD_CLOUD_DATASEEKER_PROXY_ENV` | 固定值 `"1"` | 代理开关 |
| `AD_CLOUD_LOG_DIR` | `str(Path(__file__).parent / "ad_cloud" / "logs")` | 日志目录 |

---

## 阶段 3：理解用户意图并参考原子能力

### 3.1 阅读原子能力参考

**必须先阅读 SKILL 目录中的 `event_search.py`**，理解所有可用函数：

```bash
SKILL_DIR="$HOME/.claude/skills/event-search"
cat "$SKILL_DIR/event_search.py"
```

重点关注：
- 每个函数的**参数**（类型、含义、必填/可选）
- 每个函数的**返回值**（类型、结构）
- **环境变量设置**代码（必须在 import 之前设置）
- **SDK 导入**语句

### 3.2 分析用户意图

根据用户描述，确定需要哪些函数组合。例如：

| 用户意图 | 需要的函数 |
|---|---|
| "查 JIRA PILOT-749849 的事件" | `query_by_jira_id` |
| "查这个 ADRN 有哪些通道" | `query_by_adrn` |
| "查某辆车最近一周的量产事件" | `query_prod_events` |
| "查事件 11625878214 的 ADRN" | `query_event_detail` |
| "下载这个 ADRN 的数据" | `download_by_adrn` |
| "查一下有哪些可用标签" | `query_available_tags` |

### 3.3 收集缺失参数

从用户消息中提取已有参数，缺少的逐项询问。

---

## 阶段 4：生成代码并执行

### 4.1 生成脚本

**不要直接执行 `event_search.py`**。而是根据阶段 3 的分析，**生成一个新的 Python 脚本**，只包含用户需要的功能。

脚本结构（凭证写入代码，可独立运行）：

```python
#!/usr/bin/env python3
"""<用户意图描述>"""

# ── 必填环境变量（必须在所有 import 之前设置，缺一不可）───────────────────
import os
from pathlib import Path

os.environ["AD_CLOUD_DATASET_CALL_ENV"] = "tjv1"                      # [必填] SDK 环境
os.environ["XIAOMI_IAM_ACCESS_KEY_ID"] = "<access_key>"               # [必填] MCP 获取
os.environ["XIAOMI_IAM_SECRET_ACCESS_KEY"] = "<secret_key>"           # [必填] MCP 获取
os.environ["AD_CLOUD_XIAOMI_DEPARTMENT"] = "<cas_dept>"               # [必填] MCP 获取
os.environ["XIAOMI_USERNAME"] = "<username>"                           # [必填] MCP 获取
os.environ["EVENT_TYPE"] = "prod"                                      # [必填] prod 或 test
os.environ["AD_CLOUD_DATASEEKER_PROXY_ENV"] = "1"                     # [必填] 代理开关
os.environ["AD_CLOUD_LOG_DIR"] = str(Path(__file__).parent / "ad_cloud" / "logs")  # [必填] 日志目录

# 必填校验 — 缺失则立即报错，避免运行时才暴露
_REQUIRED = [
    "XIAOMI_IAM_ACCESS_KEY_ID", "XIAOMI_IAM_SECRET_ACCESS_KEY",
    "AD_CLOUD_XIAOMI_DEPARTMENT", "XIAOMI_USERNAME",
]
_missing = [k for k in _REQUIRED if not os.environ.get(k)]
if _missing:
    raise SystemExit(f"❌ 缺少必填环境变量: {', '.join(_missing)}")

# ── SDK 导入（参考 event_search.py 中的导入语句）──────────────
import json
from ad_cloud.event import EventSearcher, seeker
# ... 按需导入

# ── 查询逻辑（参考 event_search.py 中的函数实现）──────────────
# <根据用户意图编写的代码>

# ── 结果输出 ──────────────────────────────────────────────────
print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
```

将脚本保存到用户工作目录：

```bash
# 例如保存为 $CWD/search_<query_type>.py
```

### 4.2 执行脚本

```bash
CWD="$(pwd)"
cd "$CWD" && .venv/bin/python search_<query_type>.py
```

> ⚠️ **必须使用 `$CWD/.venv/bin/python` 完整路径。**

执行完成后展示结果并报告 JSON 输出路径。

---

## 常见问题

### 环境异常
重新执行安装：
```bash
CWD="$(pwd)"
SKILL_DIR="$HOME/.claude/skills/event-search"
cp "$SKILL_DIR/setup_env.sh" "$CWD/setup_env.sh"
cd "$CWD" && bash setup_env.sh
```

### 查询无结果
- 检查 `EVENT_TYPE` 设置（prod/test）
- 确认 ADRN/JIRA ID/事件 ID 格式正确
- 确认时间范围合理

### 权限不足
- 确认 AK/SK 有对应数据的访问权限
- 确认部门信息正确
