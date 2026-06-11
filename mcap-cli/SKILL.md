---
name: mcap-cli
description: 操作 MCAP 文件的命令行工具，支持读取、写入、转换、分析 MCAP 文件。适用场景：用户说"查看 mcap"、"提取通道"、"过滤数据"、"转换格式"、"mcap info"、"合并 mcap"、"检查 mcap 文件"、"mcap 文件损坏"等。核心命令：cat（读取消息）、info（文件分析）、filter（过滤通道/时间）、merge（合并文件）、doctor（诊断损坏）、recover（恢复文件）。用于自动驾驶和机器人数据记录的二进制文件格式。
---

# mcap-cli Skill

你的任务是：**理解用户意图 → 选择正确命令 → 生成并执行命令 → 处理错误**。

mcap-cli 是 Foxglove 开发的 MCAP 文件格式命令行工具，版本 v0.0.62，支持高效的机器人数据读写、转换和分析。

**按以下流程执行：**

---

## ⚠️ 强制规则（必须严格遵守）

1. **禁止删除用户的原始 MCAP 文件**
   - filter、merge、compress、recover 等命令会生成新文件，不得删除源文件
   - 若需清理，必须明确告知用户并由用户自行决定

2. **输出文件必须指定 `-o` 参数**
   - filter、merge、compress、decompress、convert、recover 命令必须显式指定输出路径
   - 示例：`mcap filter input.mcap -o output.mcap`

3. **时间范围参数必须使用正确格式**
   - `mcap filter` 支持：RFC3339（如 `2024-01-15T10:00:00+08:00`）或纳秒时间戳
   - `mcap cat` 仅支持：`--start-nsecs`/`--end-nsecs`（纳秒）或 `--start-secs`/`--end-secs`（秒，已弃用）
   - ⚠️ `mcap cat` **不支持** RFC3339 格式的 `--start`/`--end` 参数

4. **大文件处理建议**
   - 超过 1GB 的文件建议使用压缩格式（zstd）
   - 处理超大文件时注意磁盘空间（输出文件可能接近输入文件大小）

5. **正则表达式转义**
   - 在 bash 中使用正则表达式时，注意转义特殊字符
   - 示例：`mcap filter data.mcap -y "/camera/(front|back)"` → 使用引号包裹

---

## 快速参考：命令速查表

| 命令 | 功能 | 高频使用 |
|------|------|---------|
| `mcap info <file>` | 查看文件统计信息（通道、消息数、时间范围） | ⭐⭐⭐ |
| `mcap cat <file>` | 读取/拼接消息到标准输出 | ⭐⭐⭐ |
| `mcap filter <file>` | 按通道/时间过滤到新文件 | ⭐⭐⭐ |
| `mcap merge <file1> <file2>` | 合并多个文件 | ⭐⭐ |
| `mcap doctor <file>` | 检查文件结构完整性 | ⭐⭐ |
| `mcap get <file>` | 从文件中读取单条记录 | ⭐ |
| `mcap recover <file>` | 从损坏文件恢复数据 | ⭐ |
| `mcap list <file>` | 列出所有记录（schema/channel/message） | ⭐ |
| `mcap du <file>` | 查看空间占用详情 | ⭐ |
| `mcap convert <bag>` | 转换 ROS bag 文件 | ⭐ |
| `mcap compress <file>` | 创建压缩副本 | ⭐ |
| `mcap decompress <file>` | 创建解压副本 | ⭐ |
| `mcap add <file>` | 向现有文件添加记录 | ⭐ |
| `mcap sort <file>` | 按时间排序重写文件 | ⭐ |

---

## 核心操作

### 一、数据读取（Reading Data）

#### 1.1 读取消息内容：`mcap cat`

**基本用法：**
```bash
# 读取文件中所有消息
mcap cat data.mcap

# 读取指定通道的消息
mcap cat data.mcap --topics "/camera/front,/lidar"

# 按时间范围读取
mcap cat data.mcap --start-nsecs 1705286400000000000 --end-nsecs 1705287000000000000

# 输出为 JSON 格式（支持 ros1, protobuf, json 编码）
mcap cat data.mcap --json
```

**参数说明：**
- `--topics`：逗号分隔的通道列表
- `--start-nsecs` / `--end-nsecs`：纳秒时间戳
- `--start-secs` / `--end-secs`：秒级时间戳（已弃用）
- `--json`：以 JSON 格式输出消息

**示例：查看特定通道的最近 10 条消息**
```bash
mcap cat data.mcap --topics "/localization/kinetic_localization" | tail -10
```

**注意**：`mcap cat` 支持多个输入文件（`mcap cat [file]...`），会将所有文件的消息按时间顺序拼接输出。

#### 1.2 获取特定记录：`mcap get`

```bash
# 获取 attachment（附件）
mcap get attachment data.mcap --name "calibration.json"

# 获取 metadata（元数据）
mcap get metadata data.mcap --name "rosbag_header"
```

**使用场景**：快速提取特定的元数据或附件，无需读取整个文件。

#### 1.3 列出文件记录：`mcap list`

```bash
# 列出所有记录类型
mcap list data.mcap

# 列出 schema
mcap list data.mcap --schemas

# 列出 channel
mcap list data.mcap --channels
```

---

### 二、文件分析（File Analysis）

#### 2.1 查看文件信息：`mcap info`

**基本用法：**
```bash
# 查看文件统计信息
mcap info data.mcap
```

**输出示例：**
```
library: mcap
profile: ros1
messages: 1,234,567
duration: 1h23m45s
start: 2024-01-15T10:00:00+08:00
end: 2024-01-15T11:23:45+08:00
schemas:
  - name: std_msgs/String
    encoding: ros1
channels:
  - topic: /camera/front
    messageCount: 500,000
  - topic: /lidar
    messageCount: 734,567
attachments: 0
metadata: 2
```

**提示**：`-v, --verbose` 是全局标志，用于启用详细日志输出（调试用），不是 info 专用的详细信息模式。

#### 2.2 查看空间占用：`mcap du`

```bash
# 查看各通道的空间占用
mcap du data.mcap

# 输出示例：
# /camera/front    1.2 GB
# /lidar           2.3 GB
# /localization    0.1 GB
```

---

### 三、数据转换（Data Transformation）

#### 3.1 过滤通道/时间：`mcap filter` ⭐

**这是最常用的数据提取命令**

**按通道过滤：**
```bash
# 提取单个通道
mcap filter data.mcap -y "/camera/front" -o filtered.mcap

# 提取多个通道（正则表达式）
mcap filter data.mcap -y "/camera/front" -y "/camera/back" -o filtered.mcap

# 使用正则匹配
mcap filter data.mcap -y "/camera/(front|back)" -o filtered.mcap

# 排除某些通道
mcap filter data.mcap -n "/diagnostics" -o filtered.mcap
```

**按时间范围过滤：**
```bash
# 使用 RFC3339 时间格式（推荐）
mcap filter data.mcap \
  --start "2024-01-15T10:00:00+08:00" \
  --end "2024-01-15T11:00:00+08:00" \
  -o filtered.mcap

# 使用纳秒时间戳
mcap filter data.mcap \
  --start 1705286400000000000 \
  --end 1705287000000000000 \
  -o filtered.mcap
```

**组合过滤：**
```bash
# 同时按通道和时间过滤
mcap filter data.mcap \
  -y "/camera/front" \
  --start "2024-01-15T10:00:00+08:00" \
  --end "2024-01-15T11:00:00+08:00" \
  -o filtered.mcap
```

**保留最后一个消息（用于状态初始化）：**
```bash
# 即使在时间范围外，也保留该通道的最后一条消息
mcap filter data.mcap \
  -y "/localization/kinetic_localization" \
  -l "/localization/kinetic_localization" \
  --start "2024-01-15T10:00:00+08:00" \
  -o filtered.mcap
```

**参数说明：**
- `-y, --include-topic-regex`：包含的通道（支持正则）
- `-n, --exclude-topic-regex`：排除的通道（支持正则）
- `-l, --last-per-channel-topic-regex`：保留最后一条消息的通道
- `--start / --end`：时间范围（RFC3339 或纳秒）
- `-o, --output`：输出文件路径（必填）
- `--output-compression`：输出文件压缩格式（默认 zstd）
- `--include-attachments`：是否包含附件（默认不包含）
- `--include-metadata`：是否包含元数据（默认包含）
- `--chunk-size`：输出文件 chunk 大小（默认 4MB）

#### 3.2 合并文件：`mcap merge`

```bash
# 合并两个文件（按时间戳排序）
mcap merge file1.mcap file2.mcap -o merged.mcap

# 合并多个文件
mcap merge file1.mcap file2.mcap file3.mcap -o merged.mcap
```

**参数说明：**
- `-o, --output-file`：输出文件路径（必填，注意长标志是 `--output-file` 而非 `--output`）

**注意事项：**
- 输出文件按 log time 排序
- 相同的 schema/channel 会自动合并
- metadata 和 attachment 会保留

#### 3.3 压缩/解压文件

```bash
# 压缩文件（使用 zstd 算法）
mcap compress data.mcap -o compressed.mcap

# 解压文件
mcap decompress compressed.mcap -o data.mcap

# 指定压缩算法（none, lz4, zstd）
mcap filter data.mcap -y "/camera" --output-compression lz4 -o filtered.mcap
```

#### 3.4 排序文件

```bash
# 按 log time 排序重写文件
mcap sort unsorted.mcap -o sorted.mcap
```

---

### 四、数据写入（Data Writing）

#### 4.1 转换 ROS bag 文件

```bash
# 将 ROS bag 转换为 MCAP
mcap convert data.bag -o data.mcap
```

#### 4.2 添加记录

```bash
# 向现有 MCAP 文件添加记录
mcap add data.mcap --schema-id 1 --channel-id 1 --data @message.bin
```

---

### 五、错误处理（Error Handling）

#### 5.1 诊断损坏文件：`mcap doctor`

```bash
# 检查文件结构完整性
mcap doctor corrupted.mcap
```

**输出示例：**
```
✓ Header valid
✓ Footer valid
✓ Index valid
✗ Found 3 corrupted chunks at offsets: 0x1000, 0x2000, 0x3000
✓ Schema IDs unique
✓ Channel IDs unique
```

#### 5.2 恢复损坏文件：`mcap recover`

```bash
# 尝试从损坏文件恢复数据
mcap recover corrupted.mcap -o recovered.mcap
```

**恢复策略：**
- 跳过损坏的 chunk
- 保留所有可读的消息
- 重建索引

**验证恢复结果：**
```bash
mcap doctor recovered.mcap
mcap info recovered.mcap
```

---

## 高级功能

### 一、压缩配置

**压缩算法对比：**

| 算法 | 压缩率 | 压缩速度 | 解压速度 | 推荐场景 |
|------|--------|---------|---------|---------|
| `none` | 0% | 最快 | 最快 | 临时文件、调试 |
| `lz4` | ~50% | 快 | 最快 | 高频读取场景 |
| `zstd` | ~60% | 中等 | 快 | 长期存储（默认） |

**设置输出压缩：**
```bash
# 使用 lz4 压缩（解压最快）
mcap filter data.mcap -y "/camera" --output-compression lz4 -o filtered.mcap

# 不压缩（处理最快）
mcap filter data.mcap -y "/camera" --output-compression none -o filtered.mcap
```

### 二、Chunk Size 调优

**Chunk 是 MCAP 的基本存储单位，影响压缩效率和读取性能。**

```bash
# 设置 chunk 大小（默认 4MB）
mcap filter data.mcap -y "/camera" --chunk-size 8388608 -o filtered.mcap

# 推荐：
# - 小 chunk（1-4MB）：频繁读取、实时播放
# - 大 chunk（8-16MB）：长期存储、顺序读取
```

### 三、Strict Mode（严格模式）

**强制消息按时间顺序排列：**
```bash
# 启用严格模式（要求消息 log time 单调递增）
mcap cat data.mcap --strict-message-order

# 用于验证文件完整性
mcap info data.mcap --strict-message-order
```

### 四、性能调优

**大文件处理建议：**

1. **使用压缩减少 I/O**
   ```bash
   # 压缩格式减少磁盘 I/O，提升处理速度
   mcap filter large.mcap -y "/camera" --output-compression zstd -o filtered.mcap
   ```

2. **调整 chunk size**
   ```bash
   # 大 chunk 提升压缩率，减少索引开销
   mcap filter large.mcap --chunk-size 16777216 -o filtered.mcap
   ```

3. **并行处理**
   ```bash
   # 拆分文件后并行处理
   mcap filter data.mcap --start "2024-01-15T00:00:00+08:00" --end "2024-01-15T12:00:00+08:00" -o part1.mcap &
   mcap filter data.mcap --start "2024-01-15T12:00:00+08:00" --end "2024-01-16T00:00:00+08:00" -o part2.mcap &
   wait
   ```

### 五、配置文件

**支持全局配置文件 `~/.mcap.yaml`：**
```yaml
# 默认压缩算法
compression: zstd

# 默认 chunk 大小
chunkSize: 4194304

# 严格模式
strictMessageOrder: false
```

**使用配置文件：**
```bash
mcap filter data.mcap -y "/camera" -o filtered.mcap --config ~/.mcap.yaml
```

---

## 工作流指南

### 决策树：用户意图 → 命令选择

```
用户意图                              推荐命令
───────────────────────────────────────────────────────
"查看 mcap 文件信息"              → mcap info <file>
"这个文件有哪些通道"              → mcap info <file> 或 mcap list <file>
"提取某些通道的数据"              → mcap filter <file> -y <topics> -o <output>
"按时间切片"                      → mcap filter <file> --start <t1> --end <t2> -o <output>
"读取消息内容"                    → mcap cat <file> --topics <topics>
"合并多个 mcap 文件"              → mcap merge <files...> -o <output>
"文件损坏了怎么办"                → mcap doctor <file> → mcap recover <file> -o <output>
"把 bag 转成 mcap"                → mcap convert <bag> -o <output>
"压缩文件节省空间"                → mcap compress <file> -o <output>
"查看各通道占用空间"              → mcap du <file>
```

### 典型工作流示例

#### 场景 1：从大型 MCAP 提取特定通道

```bash
# 步骤 1：查看文件信息，确认通道名称
mcap info large_data.mcap

# 步骤 2：提取指定通道（支持正则）
mcap filter large_data.mcap \
  -y "/camera/front" \
  -y "/lidar" \
  -o filtered.mcap \
  --output-compression zstd

# 步骤 3：验证结果
mcap info filtered.mcap

# 步骤 4：检查空间节省
ls -lh large_data.mcap filtered.mcap
```

**✓ 验证命令**：
```bash
# 验证通道存在且消息数合理
mcap info filtered.mcap | grep -E "(camera|lidar)"

# 验证文件完整性
mcap doctor filtered.mcap
```

#### 场景 2：按时间范围切片 + 通道过滤

```bash
# 提取 10:00-11:00 的 camera 和 lidar 数据
mcap filter data.mcap \
  -y "/camera/(front|back)" \
  -y "/lidar" \
  --start "2024-01-15T10:00:00+08:00" \
  --end "2024-01-15T11:00:00+08:00" \
  -o sliced.mcap

# 验证时间范围
mcap info sliced.mcap
```

**✓ 验证命令**：
```bash
# 验证时间范围正确（应为 1 小时）
mcap info sliced.mcap | grep duration

# 验证通道数量正确
mcap list sliced.mcap --channels | grep -E "camera|lidar"
```

#### 场景 3：诊断并恢复损坏文件

```bash
# 步骤 1：诊断文件
mcap doctor corrupted.mcap

# 步骤 2：尝试恢复
mcap recover corrupted.mcap -o recovered.mcap

# 步骤 3：验证恢复结果
mcap doctor recovered.mcap
mcap info recovered.mcap

# 步骤 4：对比文件大小，评估数据丢失
ls -lh corrupted.mcap recovered.mcap
```

**✓ 验证命令**：
```bash
# 验证恢复文件无错误
mcap doctor recovered.mcap | grep -E "(✓|✗)"

# 验证消息数量合理（对比原始文件）
mcap info recovered.mcap | grep messages
```

#### 场景 4：批量处理多个文件

```bash
# 批量转换 bag 文件
for bag in *.bag; do
  mcap convert "$bag" -o "${bag%.bag}.mcap"
done

# 批量提取通道
for mcap in *.mcap; do
  mcap filter "$mcap" -y "/camera/front" -o "filtered_${mcap}"
done
```

**✓ 验证命令**：
```bash
# 验证所有转换后的文件都有效
for mcap in *.mcap; do
  echo "Checking $mcap:"
  mcap info "$mcap" | head -5
done

# 统计处理结果
ls -1 *.mcap | wc -l
```

#### 场景 5：查看特定通道的消息内容

```bash
# 查看最近 10 条消息
mcap cat data.mcap --topics "/localization/kinetic_localization" | tail -10

# 以 JSON 格式输出
mcap cat data.mcap --topics "/localization/kinetic_localization" --json | head -5

# 导出到文件
mcap cat data.mcap --topics "/localization/kinetic_localization" --json > messages.json
```

**✓ 验证命令**：
```bash
# 验证导出的 JSON 文件格式正确
cat messages.json | head -1 | jq . 2>/dev/null && echo "✅ JSON 格式有效"

# 验证消息数量
wc -l messages.json
```

---

## 常见问题

### 1. 通道不存在错误

**错误信息：**
```
Error: no channels matched topics: /camera/left
```

**解决方案：**
```bash
# 步骤 1：查看文件中所有可用通道
mcap info data.mcap

# 步骤 2：确认通道名称（注意拼写和大小写）
mcap list data.mcap --channels

# 步骤 3：使用正确的通道名称或正则表达式
mcap filter data.mcap -y "/camera/(front|back)" -o filtered.mcap
```

### 2. 时间范围参数错误

**错误信息：**
```
Error: invalid time format
```

**解决方案：**
```bash
# 错误示例（秒级时间戳已弃用）
mcap filter data.mcap --start-secs 1705286400

# 正确示例（RFC3339 格式）
mcap filter data.mcap --start "2024-01-15T10:00:00+08:00"

# 或使用纳秒时间戳
mcap filter data.mcap --start 1705286400000000000
```

### 3. 文件损坏

**症状：**
- `mcap info` 报错
- `mcap cat` 无法读取
- 文件大小异常

**诊断步骤：**
```bash
# 步骤 1：检查文件结构
mcap doctor corrupted.mcap

# 步骤 2：尝试恢复
mcap recover corrupted.mcap -o recovered.mcap

# 步骤 3：验证恢复结果
mcap info recovered.mcap
```

### 4. 磁盘空间不足

**错误信息：**
```
Error: write error: no space left on device
```

**解决方案：**
```bash
# 步骤 1：检查磁盘空间
df -h /path/to/output

# 步骤 2：使用压缩减少输出大小
mcap filter large.mcap -y "/camera" --output-compression zstd -o filtered.mcap

# 步骤 3：分批处理
mcap filter data.mcap --start "2024-01-15T00:00:00+08:00" --end "2024-01-15T06:00:00+08:00" -o part1.mcap
```

### 5. 权限不足

**错误信息：**
```
Error: permission denied
```

**解决方案：**
```bash
# 检查文件权限
ls -l data.mcap

# 修改权限
chmod 644 data.mcap

# 或使用 sudo（谨慎）
sudo mcap info data.mcap
```

### 6. 正则表达式错误

**错误信息：**
```
Error: invalid regex pattern
```

**解决方案：**
```bash
# 错误示例（未转义特殊字符）
mcap filter data.mcap -y /camera/(front|back) -o filtered.mcap

# 正确示例（使用引号包裹）
mcap filter data.mcap -y "/camera/(front|back)" -o filtered.mcap

# 或转义括号
mcap filter data.mcap -y "/camera/\(front\|back\)" -o filtered.mcap
```

### 7. 大文件处理性能问题

**症状：**
- 处理速度慢
- 内存占用高

**优化建议：**
```bash
# 1. 使用压缩减少 I/O
mcap filter large.mcap --output-compression zstd -o filtered.mcap

# 2. 增大 chunk size 提升压缩率
mcap filter large.mcap --chunk-size 16777216 -o filtered.mcap

# 3. 按时间分片处理
mcap filter large.mcap --start "2024-01-15T00:00:00+08:00" --end "2024-01-15T12:00:00+08:00" -o part1.mcap
```

---

## 其他命令参考

以下是低频使用命令的简要说明，详细用法请使用 `mcap <command> --help`。

| 命令 | 功能 | 使用场景 |
|------|------|---------|
| `mcap version` | 查看版本信息 | 确认安装版本 |
| `mcap completion` | 生成 shell 补全脚本 | 提升命令行体验 |
| `mcap add` | 向文件添加记录 | 手动构建 MCAP 文件 |

---

## 参考链接

- **官方文档**: https://mcap.dev/guides/cli
- **GitHub 仓库**: https://github.com/foxglove/mcap
- **MCAP 格式规范**: https://mcap.dev/spec
- **Release 页面**: https://github.com/foxglove/mcap/releases
