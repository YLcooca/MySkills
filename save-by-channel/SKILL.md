---
name: save-by-channel
description: 按 ADRN 提取指定 channel 并生成本地 MCAP 文件。遇到"提取通道/下载数据/导出MCAP/save by channel"相关任务时，必须先调用本 skill 阅读完整流程指导，再结合 ad-cloud-mcp-oversea MCP 工具执行。适用场景：用户说"帮我提取 adrn 为 xxx 的 xxx 通道"、"下载视频数据"、"提取 camera 数据"、"生成 mcap 文件"、"save by channel"、"按通道过滤 mcap"、"批量提取 channel"等。负责从零配置本地 Python 环境、安装依赖、生成执行脚本并运行，结果保存到本地目录。
---

# Save-by-Channel 批量提取 Skill

你的任务是：**从零引导用户**完成环境配置，并生成所有必要的代码文件，最终执行批量 MCAP channel 提取任务。用户本地没有任何项目代码，你需要将全部代码写入本地文件。

按以下阶段顺序执行，每个阶段完成后确认再进入下一阶段。

**第一步必须是环境检查（阶段 -1），绝对不能跳过或后置。**

---

## ⚠️ 强制规则（必须严格遵守，任何情况下不得违反）

1. **禁止使用 `rm`、`rmdir`、`unlink` 等任何删除命令删除用户的文件或目录。**
   - 包括但不限于：`rm -rf`、`rm -r`、`rm -f`、`rmdir`、`find ... -delete` 等一切会导致文件/目录被删除的命令。
   - 若需清理临时文件，必须明确告知用户并由用户自行决定是否删除。

2. **输出目录（OUTPUT_DIR）必须由用户明确输入，禁止使用任何默认值。**
   - 不得使用 `output`、`$WORK_DIR/output` 或任何自动推断的路径。
   - 用户未填写时必须重复询问，直到收到有效路径为止。
   - 禁止跳过阶段 5 第 3 步。

3. **阶段 6.1 的参数确认步骤不得跳过。**
   - 必须向用户展示全部 4 个参数（ADRN 列表、Channel 列表、输出目录、并发线程数），等待用户回车确认后才能执行。
   - 禁止在未经用户确认的情况下直接进入阶段 6.2 执行脚本。

---

---

## 阶段 -1：环境检查（强制第一步）

**在做任何其他操作之前，必须先检查环境是否已就绪。** 执行以下检查命令：

```bash
WORK_DIR="$(pwd)/ad-cloud-workspace"
# 自动探测 skill 目录（适配 OpenCode / Claude Code / MiCode）
SKILL_DIR=""
for _d in "$HOME/.micode/skills/save-by-channel" "$HOME/.opencode/skills/save-by-channel" "$HOME/.claude/skills/save-by-channel"; do
  if [ -f "$_d/setup_env.sh" ]; then SKILL_DIR="$_d"; break; fi
done
echo "=== 环境检查 ==="
# 1. 检查 setup_env.sh（skill 目录中，最基础的依赖）
if [ -n "$SKILL_DIR" ]; then echo "✅ setup_env.sh 存在: $SKILL_DIR/setup_env.sh"; else echo "❌ setup_env.sh 不存在（已检查 .opencode/.claude/.micode）"; fi
# 2. 检查工作目录
if [ -d "$WORK_DIR" ]; then echo "✅ 工作目录存在: $WORK_DIR"; else echo "❌ 工作目录不存在: $WORK_DIR"; fi
# 3. 检查虚拟环境
if [ -f "$WORK_DIR/.venv/bin/python" ]; then echo "✅ 虚拟环境存在"; else echo "❌ 虚拟环境不存在"; fi
# 4. 检查 ad-cloud-sdk 是否已安装
if [ -f "$WORK_DIR/.venv/bin/python" ] && "$WORK_DIR/.venv/bin/python" -c "import ad_cloud" 2>/dev/null; then echo "✅ ad-cloud-sdk 已安装"; else echo "❌ ad-cloud-sdk 未安装"; fi
echo "=== 检查完毕 ==="

# 删除可能存在的旧脚本，确保阶段 4 生成全新版本
rm -f "$WORK_DIR/mcap_extractor.py" "$WORK_DIR/run_save_by_channel.py"
echo "✅ 已清理旧脚本文件"
```

根据检查结果决策：

| 情况 | 动作 |
|---|---|
| **全部 ✅**（目录+venv+SDK+脚本都存在） | 向用户报告环境就绪，**跳过阶段 0~2**，直接进入**阶段 3** |
| **目录存在但 venv/SDK 缺失** | 向用户报告环境部分损坏，进入**阶段 0 & 1 & 2**修复 |
| **目录不存在** | 向用户报告需要从零配置，进入**阶段 0 & 1 & 2** |

**禁止**：跳过环境检查直接进入阶段 0 创建目录，或在未检查的情况下假设环境不存在。

---

## 阶段 0 & 1 & 2：环境准备

**无需询问用户**，直接在当前工作目录下创建 `ad-cloud-workspace` 作为工作目录：

```bash
pwd
```

将上面输出的路径记为 `<CWD>`，然后执行：

```bash
mkdir -p "<CWD>/ad-cloud-workspace"
```

将 `WORK_DIR` 记为 `<CWD>/ad-cloud-workspace`（绝对路径），后续所有命令中的 `$WORK_DIR` 均替换为该实际路径。

从 skill 目录复制 `setup_env.sh` 到 `$WORK_DIR`，执行以下命令（自动探测 skill 目录）：

```bash
SKILL_DIR=""
for _d in "$HOME/.micode/skills/save-by-channel" "$HOME/.opencode/skills/save-by-channel" "$HOME/.claude/skills/save-by-channel"; do
  if [ -f "$_d/setup_env.sh" ]; then SKILL_DIR="$_d"; break; fi
done
if [ -z "$SKILL_DIR" ]; then echo "❌ 找不到 setup_env.sh，请确认 skill 已正确安装"; exit 1; fi
cp "$SKILL_DIR/setup_env.sh" "$WORK_DIR/setup_env.sh"
echo "✅ 已复制 setup_env.sh 从 $SKILL_DIR"
```

然后执行环境安装脚本（该脚本会自动检查并按需安装 uv、创建 venv、安装 pip、安装 ad-cloud-sdk，已安装的组件会跳过）：

```bash
cd $WORK_DIR && bash setup_env.sh
```

> ⚠️ **重要：ad-cloud-sdk 安装过程可能耗时较长（5~15 分钟），期间必须持续等待，不得中断或超时放弃。**
> 执行 Bash 工具时请将 timeout 设置为 **1800000**（30 分钟），直到命令自行成功退出或报错退出为止。

---

## 阶段 3：配置环境变量

### 3.1 获取用户凭证（通过 ad-cloud-mcp-oversea）

`XIAOMI_IAM_ACCESS_KEY_ID`、`XIAOMI_IAM_SECRET_ACCESS_KEY`、`AD_CLOUD_XIAOMI_DEPARTMENT`、`XIAOMI_USERNAME` 四个变量**不使用硬编码默认值**，必须从 `ad-cloud-mcp-oversea` MCP 动态获取。

**步骤一：检查MCP工具 `ad-cloud-mcp-oversea` 是否可用**

尝试调用MCAP工具 `ad-cloud-mcp-oversea` 的 `get_user_info` 工具。

- **若调用成功**，返回结构如下，直接提取四个字段：
  ```json
  {
    "access_key": "...",
    "secret_key": "...",
    "username": "...",
    "cas_dept": "..."
  }
  ```
  字段映射关系：
  | MCP 返回字段 | 环境变量 |
  |---|---|
  | `access_key` | `XIAOMI_IAM_ACCESS_KEY_ID` |
  | `secret_key` | `XIAOMI_IAM_SECRET_ACCESS_KEY` |
  | `username` | `XIAOMI_USERNAME` |
  | `cas_dept` | `AD_CLOUD_XIAOMI_DEPARTMENT` |

- **若 MCP 不存在或调用失败**，告知用户：
  > ⚠️ 未检测到 `ad-cloud-mcp-oversea` MCP，无法自动获取凭证。
  > 请参考文档配置该 MCP：https://mi.feishu.cn/wiki/DhO3wlhYXiUmLukc4zxcAC03nCb
  > 配置完成后重新开始本流程。

**步骤二：将获取到的凭证写入脚本的 `_ENV_DEFAULTS`**

将四个实际值填入 `run_save_by_channel.py` 的 `_ENV_DEFAULTS`（在阶段 4 生成文件后执行，或生成时直接填入）：

```python
_ENV_DEFAULTS = {
    "AD_CLOUD_DATASET_CALL_ENV": "tjv1",
    "XIAOMI_IAM_ACCESS_KEY_ID": "<access_key 实际值>",
    "XIAOMI_IAM_SECRET_ACCESS_KEY": "<secret_key 实际值>",
    "AD_CLOUD_XIAOMI_DEPARTMENT": "<cas_dept 实际值>",
    "XIAOMI_USERNAME": "<username 实际值>",
    "EVENT_TYPE": "prod",
    "AD_CLOUD_DATASEEKER_PROXY_ENV": "1",
}
# AD_CLOUD_LOG_DIR 单独设置（依赖 Path，须在 import pathlib 之后）
if "AD_CLOUD_LOG_DIR" not in os.environ:
    os.environ["AD_CLOUD_LOG_DIR"] = str(Path(__file__).parent / "ad_cloud" / "logs")
```

---

## 阶段 4：生成核心代码文件

将以下两个文件写入 `$WORK_DIR`。**如果文件已存在，必须先删除再写入新内容，确保完全替换为最新版本，不可保留旧内容。**

### 4.1 写入 `mcap_extractor.py`

**⚠️ 重要：如果 `$WORK_DIR/mcap_extractor.py` 已存在，必须先删除再写入，不可部分修改。**

写入 `$WORK_DIR/mcap_extractor.py`，内容如下：

```python
"""
McapChannelExtractor
"""

import logging
import time
from typing import List, Set

from mcap import reader as mcap_reader_mod
from mcap import writer as mcap_writer_mod
from mcap.writer import CompressionType

from ad_cloud.common.http_utils import proxy_client
from ad_cloud.record.common import get_fsspec_filesystem

logger = logging.getLogger(__name__)


class McapChannelExtractor:
    """MCAP 文件 channel 提取器。

    从一个或多个 MCAP 文件中提取指定 channel 的消息，同时保留完整的
    metadata 和 attachment，写入新的 MCAP 文件。
    """

    COMPRESSION_TYPE_MAP = {
        "none": CompressionType.NONE,
        "lz4": CompressionType.LZ4,
        "zstd": CompressionType.ZSTD,
    }

    def __init__(
        self,
        output_file: str,
        channels: List[str],
        compression: str = "none",
        chunk_size: int = 1 * 1024 * 1024 * 1024,
    ):
        """
        Args:
            output_file: 输出 MCAP 文件路径（本地）
            channels: 要保留的 channel topic 列表；空列表表示保留全部
            compression: 压缩类型，可选 "none" / "lz4" / "zstd"
            chunk_size: chunk 大小（字节），默认 1 GB
        """
        self.output_file = output_file
        self.channels: Set[str] = set(channels)
        self.compression = compression
        self.chunk_size = chunk_size

        # 统计信息
        self.total_messages: int = 0
        self.extracted_messages: int = 0
        self.channels_found: Set[str] = set()
        self.metadata_count: int = 0
        self.attachment_count: int = 0

        # 文件来源信息
        self.source_volume: str = ""
        self.source_storage: str = ""
        self.source_fs_kws: dict = {}

    def process_files(self, record_files, adrn: str = "", print_lock=None) -> None:
        """处理多个 record 文件，写入同一个输出 MCAP。"""
        mcap_writer = mcap_writer_mod.Writer(
            self.output_file,
            use_chunking=True,
            chunk_size=self.chunk_size,
            compression=self.COMPRESSION_TYPE_MAP[self.compression],
        )

        try:
            mcap_writer.start()
            total_files = len(record_files)

            for file_idx, record_file in enumerate(record_files, 1):
                logger.info(
                    f"[{file_idx}/{total_files}] 处理文件 path={record_file.path}"
                )
                file_start = time.time()

                resp = proxy_client.get_fs_from_proxy(record_file.volume)
                fs_kws = resp["data"]
                filesystem = get_fsspec_filesystem(fs_kws)

                self.source_volume = record_file.volume
                self.source_storage = record_file.storage
                self.source_fs_kws = fs_kws

                with filesystem.open(record_file.path, "rb") as fh:
                    r = mcap_reader_mod.make_reader(fh)
                    self._write_metadata(r, mcap_writer)
                    self._write_attachments(r, mcap_writer)
                    file_schema_map: dict = {}
                    file_channel_map: dict = {}
                    self._extract_and_write_messages(r, mcap_writer, file_schema_map, file_channel_map)

                elapsed = time.time() - file_start
                logger.info(
                    f"[{file_idx}/{total_files}] 完成 耗时={elapsed:.1f}s "
                    f"msgs={self.extracted_messages}/{self.total_messages}"
                )

                # 每 20 个文件向对话框打印一次进度
                if file_idx % 20 == 0 or file_idx == total_files:
                    msg = (
                        f"  ⏳ {adrn or self.output_file} | "
                        f"文件进度 {file_idx}/{total_files} | "
                        f"已提取 {self.extracted_messages} 条消息"
                    )
                    if print_lock:
                        with print_lock:
                            print(msg, flush=True)
                    else:
                        print(msg, flush=True)

        finally:
            mcap_writer.finish()

    def _write_metadata(self, r, w):
        count_before = self.metadata_count
        for metadata in r.iter_metadata():
            w.add_metadata(metadata.name, metadata.metadata)
            self.metadata_count += 1
        added = self.metadata_count - count_before
        if added:
            logger.info(f"metadata +{added} 累计={self.metadata_count}")

    def _write_attachments(self, r, w):
        count_before = self.attachment_count
        for attachment in r.iter_attachments():
            w.add_attachment(
                attachment.create_time,
                attachment.log_time,
                attachment.name,
                attachment.media_type,
                attachment.data,
            )
            self.attachment_count += 1
        added = self.attachment_count - count_before
        if added:
            logger.info(f"attachment +{added} 累计={self.attachment_count}")

    def _extract_and_write_messages(self, r, w, schema_map: dict, channel_map: dict):
        topics_filter = list(self.channels) if self.channels else None

        for schema, channel, message in r.iter_messages(topics=topics_filter, log_time_order=False):
            self.total_messages += 1

            if not self.channels or channel.topic in self.channels:
                self.channels_found.add(channel.topic)

                # 注册 schema（按需）
                if schema is not None and schema.id not in schema_map:
                    new_schema_id = w.register_schema(
                        name=schema.name,
                        encoding=schema.encoding,
                        data=schema.data,
                    )
                    schema_map[schema.id] = new_schema_id
                elif schema is not None:
                    new_schema_id = schema_map[schema.id]
                else:
                    new_schema_id = 0

                # 注册 channel（按需）
                if channel.id not in channel_map:
                    new_channel_id = w.register_channel(
                        topic=channel.topic,
                        message_encoding=channel.message_encoding,
                        schema_id=new_schema_id,
                        metadata=channel.metadata,
                    )
                    channel_map[channel.id] = new_channel_id
                else:
                    new_channel_id = channel_map[channel.id]

                w.add_message(
                    channel_id=new_channel_id,
                    log_time=message.log_time,
                    data=message.data,
                    publish_time=message.publish_time,
                    sequence=message.sequence,
                )
                self.extracted_messages += 1

        logger.info(
            f"消息提取完成 | 已扫描={self.total_messages}"
            f" 已提取={self.extracted_messages}"
            f" channels_found={sorted(self.channels_found)}"
        )
```

### 4.2 写入 `run_save_by_channel.py`

**⚠️ 重要：如果 `$WORK_DIR/run_save_by_channel.py` 已存在，必须先删除再写入，不可部分修改。**

这是批量执行脚本，包含参数配置区、多线程执行、逐行进度输出和结果报告。

写入 `$WORK_DIR/run_save_by_channel.py`，内容如下：

```python
#!/usr/bin/env python3
"""
批量 Save-by-Channel 执行脚本
用途：从 AD-Cloud 按 ADRN 批量提取指定 channel，保存为本地 MCAP 文件。

使用方式：
  1. 编辑下方「用户配置区」填入 ADRN 列表、channel 列表、输出目录
  2. python run_save_by_channel.py
"""

# ── 环境变量必须在所有第三方 import 之前设置，防止包加载时读到错误值 ──────
import os
import sys

_ENV_DEFAULTS = {
    "AD_CLOUD_DATASET_CALL_ENV": "tjv1",
    "XIAOMI_IAM_ACCESS_KEY_ID": "",   # ← 由 access_key 填入
    "XIAOMI_IAM_SECRET_ACCESS_KEY": "",  # ← 由 secret_key 填入
    "AD_CLOUD_XIAOMI_DEPARTMENT": "",  # ← 由 cas_dept 填入
    "XIAOMI_USERNAME": "",             # ← 由 username 填入
    "EVENT_TYPE": "prod",
    "AD_CLOUD_DATASEEKER_PROXY_ENV": "1",
}
for _k, _v in _ENV_DEFAULTS.items():
    if _k not in os.environ:
        os.environ[_k] = _v

# AD_CLOUD_LOG_DIR 依赖 Path，单独在此处设置
import pathlib as _pathlib
if "AD_CLOUD_LOG_DIR" not in os.environ:
    os.environ["AD_CLOUD_LOG_DIR"] = str(_pathlib.Path(__file__).parent / "ad_cloud" / "logs")

import hashlib
import json
import logging
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import List

# ── 将脚本所在目录加入 sys.path（确保能 import mcap_extractor）────────────
sys.path.insert(0, str(Path(__file__).parent.resolve()))

try:
    from mcap_extractor import McapChannelExtractor
    from ad_cloud.adrn.data_seeker.records.dataclip_reader import DataclipReader
except ImportError as e:
    print(f"❌ 依赖导入失败: {e}")
    print("请确认：")
    print("  1. 虚拟环境已激活: source .venv/bin/activate")
    print("  2. 依赖已安装: .venv/bin/python -m pip install --index-url https://pkgs.d.xiaomi.net/artifactory/api/pypi/pypi-virtual/simple --trusted-host pkgs.d.xiaomi.net 'ad-cloud-sdk[adrn]==0.0.2+global.dev202603191132'")
    sys.exit(1)

# ── 日志配置 ──────────────────────────────────────────────────────────────────
# root logger 不输出任何内容到终端，全量写文件，避免日志行干扰进度输出
_log_file = os.path.join(os.path.dirname(__file__), "save_by_channel.log")
_file_handler = logging.FileHandler(_log_file, encoding="utf-8")
_file_handler.setLevel(logging.INFO)
_file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(name)s: %(message)s"))

# root logger：只写文件，不输出 stderr
_root_logger = logging.getLogger()
_root_logger.setLevel(logging.INFO)
_root_logger.addHandler(_file_handler)

# 关键：禁止 ad_cloud / mcap_extractor 的日志向上冒泡到可能有 stderr handler 的祖先
for _name in ("ad_cloud", "mcap_extractor"):
    _lg = logging.getLogger(_name)
    _lg.setLevel(logging.INFO)
    _lg.propagate = False  # 不冒泡，日志只走文件
    _lg.addHandler(_file_handler)


# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                         用户配置区（请在此填写）                           ║
# ╚══════════════════════════════════════════════════════════════════════════╝

ADRN_LIST: List[str] = [
    # 在此填入 ADRN，每行一个，例如：
    # "adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000",
    # "adr::dataclip:prod.mo5-mt.0073::1726146700000000000:1726146750000000000",
]

CHANNEL_FILTER_LIST: List[str] = [
    # 在此填入要提取的 channel 名称，例如：
    # "/localization/kinetic_localization",
    # "/sensors/lidar/mid_center_top_wide/raw",
]

# 输出目录（默认为脚本所在目录下的 output 子目录）
OUTPUT_DIR: str = ""  # ← 必填，由阶段 5 用户输入填入，禁止使用默认值

# 并发线程数（建议 2~8，根据机器性能和网络带宽调整）
MAX_WORKERS: int = 4

# ╔══════════════════════════════════════════════════════════════════════════╗
# ║                           以下代码无需修改                                ║
# ╚══════════════════════════════════════════════════════════════════════════╝


def _make_output_filename(adrn: str) -> str:
    """根据 ADRN 生成唯一的本地输出文件名。"""
    adrn_hash = hashlib.md5(adrn.encode()).hexdigest()[:10]
    ts = int(time.time())
    # 提取 ADRN 中的可读部分作为前缀
    try:
        # adr::dataclip:prod.mo5-mt.0072::start:end → prod_mo5-mt_0072
        middle = adrn.split("::")[1]  # "dataclip:prod.mo5-mt.0072"
        readable = middle.split(":", 1)[1].replace(".", "_")  # "prod_mo5-mt_0072"
    except (IndexError, AttributeError):
        readable = "unknown"
    return f"{readable}_{adrn_hash}_{ts}.mcap"


def _process_single(
    adrn: str,
    channel_filter_list: List[str],
    output_dir: str,
    counter: list,
    total: int,
    lock: threading.Lock,
) -> dict:
    """处理单个 ADRN：提取指定 channel → 保存到本地文件。"""
    result: dict = {
        "adrn": adrn,
        "status": "pending",
        "output_path": None,
        "file_size_bytes": 0,
        "file_size_mb": 0.0,
        "extracted_messages": 0,
        "total_messages": 0,
        "channels_written": [],
        "channels_not_found": [],
        "record_files_processed": 0,
        "elapsed_seconds": 0.0,
        "error": None,
    }
    t0 = time.time()

    try:
        # 1. 获取 record 文件列表
        dataclip_reader = DataclipReader(adrn)
        record_files = dataclip_reader.record_files

        if not record_files:
            result["status"] = "error"
            result["error"] = "未找到任何 record 文件"
            return result

        result["record_files_processed"] = len(record_files)

        # 2. 确定输出路径
        os.makedirs(output_dir, exist_ok=True)
        filename = _make_output_filename(adrn)
        output_path = os.path.join(output_dir, filename)

        # 3. 提取并写入
        extractor = McapChannelExtractor(
            output_file=output_path,
            channels=channel_filter_list,
        )
        extractor.process_files(record_files, adrn=adrn, print_lock=lock)

        file_size = os.path.getsize(output_path)

        result.update({
            "status": "success",
            "output_path": output_path,
            "file_size_bytes": file_size,
            "file_size_mb": round(file_size / 1024 / 1024, 2),
            "extracted_messages": extractor.extracted_messages,
            "total_messages": extractor.total_messages,
            "channels_written": sorted(extractor.channels_found),
            "channels_not_found": sorted(extractor.channels - extractor.channels_found),
            "record_files_processed": len(record_files),
        })

    except Exception as exc:
        import traceback
        result["status"] = "error"
        result["error"] = f"{type(exc).__name__}: {exc}"
        result["traceback"] = traceback.format_exc()

    finally:
        elapsed = round(time.time() - t0, 1)
        result["elapsed_seconds"] = elapsed

        with lock:
            counter[0] += 1
            done = counter[0]
            if result["status"] == "success":
                print(f"[{done}/{total}] ✅ {elapsed}s | {result['file_size_mb']}MB | {result['output_path']}", flush=True)
            else:
                print(f"[{done}/{total}] ❌ {elapsed}s | {result.get('error', 'Unknown')}", flush=True)

    return result


def main():
    # ── 前置检查 ──────────────────────────────────────────────────────────
    if not ADRN_LIST:
        print("❌ ADRN_LIST 为空，请编辑脚本在「用户配置区」填入 ADRN 列表")
        sys.exit(1)

    if not CHANNEL_FILTER_LIST:
        print("❌ CHANNEL_FILTER_LIST 为空，请填入要提取的 channel 名称")
        sys.exit(1)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # ── 打印任务摘要 ──────────────────────────────────────────────────────
    sep = "─" * 60
    script_path = str(Path(__file__).resolve())
    print(f"\n{sep}")
    print(f"  🚀 批量 Save-by-Channel")
    print(sep)
    print(f"  输出目录     : {OUTPUT_DIR}")
    print(f"  并发线程数   : {MAX_WORKERS}")
    print(f"  详细日志     : {_log_file}")
    print(f"  💡 若 AI Agent 处理超时，可在终端手动执行：")
    print(f"     cd {str(Path(script_path).parent)} && .venv/bin/python {Path(script_path).name}")
    print(sep)
    print(f"  ADRN 数量    : {len(ADRN_LIST)}")
    print(f"  Channel 数量 : {len(CHANNEL_FILTER_LIST)}")
    for ch in CHANNEL_FILTER_LIST:
        print(f"    • {ch}")
    print(f"{sep}\n")

    results = []
    lock = threading.Lock()
    counter = [0]  # 用列表包装，方便在线程间共享计数
    total = len(ADRN_LIST)

    print(f"开始处理，共 {total} 个 ADRN，并发 {MAX_WORKERS} 线程...\n", flush=True)

    # ── 多线程执行 ────────────────────────────────────────────────────────
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        future_map = {
            executor.submit(
                _process_single,
                adrn,
                CHANNEL_FILTER_LIST,
                OUTPUT_DIR,
                counter,
                total,
                lock,
            ): adrn
            for adrn in ADRN_LIST
        }
        for future in as_completed(future_map):
            try:
                results.append(future.result())
            except Exception as e:
                adrn = future_map[future]
                results.append({
                    "adrn": adrn,
                    "status": "error",
                    "error": str(e),
                })

    # ── 汇总报告 ──────────────────────────────────────────────────────────
    success_list = [r for r in results if r.get("status") == "success"]
    error_list = [r for r in results if r.get("status") != "success"]
    total_size_mb = sum(r.get("file_size_mb", 0) for r in success_list)
    total_msgs = sum(r.get("extracted_messages", 0) for r in success_list)

    print(f"\n{sep}")
    print(f"  📊 执行结果汇总")
    print(sep)
    print(f"  ✅ 成功  : {len(success_list)} / {len(ADRN_LIST)}")
    print(f"  ❌ 失败  : {len(error_list)} / {len(ADRN_LIST)}")
    print(f"  总大小   : {total_size_mb:.1f} MB")
    print(f"  总消息数 : {total_msgs:,}")
    print(f"  输出目录 : {OUTPUT_DIR}")
    print(sep)

    if success_list:
        print("\n✅ 成功文件：")
        for r in success_list:
            warn = f"  ⚠️  未找到的channel: {r['channels_not_found']}" if r.get("channels_not_found") else ""
            print(f"  [{r['elapsed_seconds']}s | {r['file_size_mb']}MB] {r['output_path']}{warn}")

    if error_list:
        print("\n❌ 失败列表：")
        for r in error_list:
            print(f"  ADRN : {r['adrn']}")
            print(f"  错误 : {r.get('error', 'Unknown')}")

    # ── 保存 JSON 报告 ────────────────────────────────────────────────────
    report_path = os.path.join(OUTPUT_DIR, f"report_{int(time.time())}.json")
    report_data = [{k: v for k, v in r.items() if k != "traceback"} for r in results]
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report_data, f, ensure_ascii=False, indent=2)

    print(f"\n📄 详细报告：{report_path}")
    print(f"📋 详细日志：{_log_file}\n")

    sys.exit(0 if not error_list else 1)


if __name__ == "__main__":
    main()
```

---

## 阶段 5：收集用户输入并填写配置

**首先从用户的原始消息中提取 ADRN 列表和 Channel 列表**，若已明确提供则直接使用，无需再询问。若未提供或不完整，再逐项向用户补问。

### 定位通道预设

若用户消息中出现以下任意关键词：`定位`、`localization`、`navi`，则 **Channel 列表无需询问**，直接使用以下预设列表：

```
/localization/rtk_gnsspvt_calib
/sensors/navi/rtk_rtcm
/perception/surround/localization
/localization/geodetic_fusion_localization
/localization/rtk_agnss_requeset
/sensors/chassis/localization
/localization/kinetic_dr_localization
/sensors/camera/mid_center_top_wide/jpeg
/localization/geodetic_sd_localization
/sensors/navi/agnss_rtcm
/localization/online_calibration_loc
/sensors/navi/novatel_pp7/inertial_explorer_raw
/sensors/navi/gnss_raw
/sensors/navi/imu
/localization/rtk_gnsspvt
/sensors/navi/rtk_rtcm_ppprtk_huace
/sensors/navi/rtk_rtcm_ppprtk_liufen
/sensors/navi/rtk_rtcm_ppprtk_qianxun
/sensors/navi/rtk_rtcm_ppprtk_qianxun_agnss
/sensors/navi/rtk_rtcm_ppprtk_qianxun_nssr
/localization/geodetic_localization
/sensors/navi/nmea_rtcm
/sensors/navi/imu_board
/pilot/admap/navigation/path_infos
/localization/kinetic_localization_status
/localization/kinetic_localization
/localization/kinloc/status
/localization/kinloc/status_2d
/localization/geodetic_kinetic_transform
/perception/status/work_condition
```

---

**逐项向用户提问，每项等用户回复后再继续，不得一次性发完所有问题。**

按以下顺序依次处理，缺什么问什么：

1. **ADRN 列表**：若用户原始消息中已包含，直接提取；否则发送：
   > 请输入 **ADRN 列表**（可以用逗号、顿号或者换行等分隔符）：
   > 格式示例：`adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000`

   等待用户回复后继续。

2. **Channel 列表**：若命中定位通道预设，直接使用预设列表，跳过此步；否则若用户原始消息中已包含，直接提取；否则发送：
   > 请输入 **Channel 过滤列表**（可以用逗号、顿号或者换行等分隔符）：
   > 格式示例：
   > ```
   > /localization/kinetic_localization
   > /sensors/lidar/mid_center_top_wide/raw
   > ```

   等待用户回复后继续。

3. 发送：
   > 请输入**输出目录**（必填，MCAP 文件将保存到此目录）：

   ⚠️ **严格禁止**：不得使用任何默认值（如 `output`、`$WORK_DIR/output` 等），不得跳过此步骤，必须等待用户明确输入路径后才能继续。用户不填则重复询问，直到收到有效路径为止。

   收到回复后，**立即检查当前用户对该目录的写权限**：

   ```bash
   OUTPUT_DIR="<用户输入的路径>"
   mkdir -p "$OUTPUT_DIR" 2>/dev/null
   if touch "$OUTPUT_DIR/.write_test" 2>/dev/null; then
       rm "$OUTPUT_DIR/.write_test"
       echo "✅ 有写权限: $OUTPUT_DIR"
   else
       echo "❌ 无写权限: $OUTPUT_DIR"
   fi
   ```

   - 有写权限 → 继续下一步
   - 无写权限 → 告知用户：
     > ❌ 当前用户对该目录没有写权限，请重新输入一个有权限的目录。

     重新询问，直到检测通过为止。

4. 发送：
   > 请输入**并发线程数**（直接回车使用默认值 `4`，建议 2~8）：

   用户直接回车或留空 → 使用 `4`。

### 5.5 填入配置到代码中

收集完用户输入后，修改 `run_save_by_channel.py` 中的配置区：

将：
```python
ADRN_LIST: List[str] = [
    # 在此填入 ADRN，每行一个，例如：
    # "adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000",
    # "adr::dataclip:prod.mo5-mt.0073::1726146700000000000:1726146750000000000",
]
```

替换为（示例）：
```python
ADRN_LIST: List[str] = [
    "adr::dataclip:prod.mo5-mt.0072::1726146648377000000:1726146693023000000",
    "adr::dataclip:prod.mo5-mt.0073::1726146700000000000:1726146750000000000",
]
```

同样修改 `CHANNEL_FILTER_LIST`、`OUTPUT_DIR`、`MAX_WORKERS`。

---

## 阶段 6：执行

### 6.1 向用户确认参数

在执行前，向用户展示本次任务的所有参数，等待用户确认后再继续：

> 请确认以下参数，**直接回车即可开始执行**：
>
> - **ADRN 列表**（共 N 个）：
>   ```
>   <逐行列出所有 ADRN>
>   ```
> - **Channel 列表**（共 N 个）：
>   ```
>   <逐行列出所有 channel>
>   ```
> - **输出目录**：`<OUTPUT_DIR>`
> - **并发线程数**：`<MAX_WORKERS>`

用户直接回车 → 开始执行；若用户修改了参数，重新填写配置后再次展示确认。

### 6.2 检查文件结构并执行

确认文件结构正确：

```bash
ls -la $WORK_DIR
# 应包含：
#   mcap_extractor.py
#   run_save_by_channel.py
#   .venv/
```

执行（直接使用 venv 内的 Python，无需 activate）：

> ⚠️ **重要：脚本处理 MCAP 数据耗时极长（每个 ADRN 可能需要数分钟到数十分钟），必须等待程序自行结束。**
> 执行 Bash 工具时请将 timeout 设置为 **0**（永不超时），直到脚本输出最终汇总报告并退出为止，绝不允许中途超时终止。

```bash
cd $WORK_DIR
.venv/bin/python run_save_by_channel.py
```

执行时将显示：
1. 任务摘要（ADRN 数量、channel 列表、输出目录）
2. 每完成一个 ADRN 输出一行进度（`[done/total] ✅/❌ 耗时 | 大小 | 路径`）
3. 汇总报告（成功/失败数量、总大小、每个输出文件路径）
4. JSON 报告和详细日志文件路径

---

## 常见问题

### 环境异常
直接重新运行 `setup_env.sh` 即可自动修复（已安装的组件会跳过）：
```bash
cd $WORK_DIR && bash setup_env.sh
```

### 内存不足（处理大文件）
- 减少并发：`MAX_WORKERS = 1`
- 一次只处理几个 ADRN

### 磁盘空间不足
- MCAP 文件较大，建议输出目录有 50GB+ 可用空间
- 可用 `df -h $OUTPUT_DIR` 检查
