---
name: perf-analysis
description: ADOS性能分析工具ados_tools的使用助手。当用户需要分析车辆性能数据、解析metrics/trace/ebpf数据、下载云端数据或分析本地mcap文件时使用此skill。适用于自动驾驶系统性能问题排查、性能指标分析、trace可视化、ebpf火焰图生成等场景。当用户提到性能分析、ados_tools、metrics、trace、ebpf、性能数据、车端数据、云端数据下载、本地数据解析、火焰图、perfetto等关键词时触发。
---

# ADOS性能分析工具使用指南

## 概述

ados_tools是一个统一的命令行工具，用于自动驾驶系统(ADOS)的性能与问题分析。它可以自动下载和解析云端数据，也可以解析本地数据文件，支持metrics、trace、ebpf三种数据类型的分析。

**前提条件**: ados_tools工具已安装在系统中。

## 核心使用场景

### 场景1: 云端数据下载与解析

当用户只知道车辆ID和问题发生时间，需要从云端下载并分析数据时使用。

**适用条件**:
- 车辆带有工控机(会自动回传性能分析数据到金山云)
- 知道车辆ID和时间范围

**基本命令格式**:
```bash
ados_tools --mode <mode> --car_id <car_id> --time "<start_time> <end_time>"
```

**时间格式**: `YYYY-MM-DD-HH-MM-SS.sss` (毫秒可以输入000)

#### 解析所有数据

```bash
ados_tools --mode all --car_id J012 --time "2025-09-26-12-08-53.000 2025-09-26-12-09-06.000"
```

#### 解析特定类型数据

```bash
# 仅解析metrics
ados_tools --mode metrics --car_id J012 --time "2025-09-26-12-08-53.000 2025-09-26-12-09-06.000"

# 解析metrics和trace
ados_tools --mode metrics trace --car_id J012 --time "2025-09-26-12-08-53.000 2025-09-26-12-09-06.000"

# 解析ebpf数据(所有SOC)
ados_tools --mode ebpf --car_id J012 --time "2025-09-26-12-08-53.000 2025-09-26-12-09-06.000"

# 解析特定SOC的ebpf数据
ados_tools --mode ebpf --car_id J012 --time "2025-09-26-12-08-53.000 2025-09-26-12-09-06.000" --add soc1
```

**重要提示**:
- 时间范围尽量精确，避免解析时间过长
- 车辆ID需要输全(例如a014而不是a14)
- 解析完成后会自动在本地启动Python server展示结果

### 场景2: 本地数据解析

当用户本地已有mcap文件需要分析时使用。

**适用条件**:
- 本地有record文件(数采、路测、Trigger录制、手动录制)
- record文件包含特定通道: metrics、trace、ebpf

#### 本地metrics解析

```bash
# 生成全量指标报告网页
ados_tools --mode metrics_local --input_dir ./2025-09-29-14-28-53_2025-09-29-14-29-06 --output_dir ./output

# 生成多个单图
ados_tools --mode metrics_local_plot --input_dir ./2025-09-29-14-28-53_2025-09-29-14-29-06 --output_dir ./output
```

#### 本地trace解析

```bash
ados_tools --mode trace_local --input_dir ./2025-09-29-14-28-53_2025-09-29-14-29-06 --output_dir ./output
```

#### 本地ebpf解析

ebpf数据支持多种格式，需要根据数据类型选择正确的参数。

**1. bcc原始文件**:
```bash
ados_tools --mode ebpf_local --raw_args --type bcc_profile \
  --manifest ./manifest_mipilot_mbf_debug_v2_1138052_20251028_12_15_17.txt \
  --input_dir ./soc_profile \
  --add soc1 \
  -t "2025-10-28-21-17-54.853 2025-10-28-21-18-00.000" \
  --output_dir ./test_output
```

**2. trigger_record文件**:
```bash
ados_tools --mode ebpf_local --raw_args --type trigger_record \
  --input_dir ./mcap \
  --add soc1 \
  -t "2025-10-30-11-18-40.000 2025-10-30-11-18-50.000" \
  --output_dir ./test_out
```

**3. perf_record文件**:
```bash
ados_tools --mode ebpf_local --raw_args --type perf_record \
  --input_dir ./observability \
  --add soc1 \
  -t "2025-10-25-14-27-20.000 2025-10-25-14-27-25.000" \
  --manifest ./ebpf/manifest_n801a_mbf_debug_1104146_20251025_10_44_28.txt \
  --mapping_file ./ebpf/soc1 \
  --output_dir ./test_out
```

**4. 差分火焰图**:
```bash
ados_tools --mode ebpf_diff --raw_args ./ebpf/soc1/oncpu/cpu0.folded ./ebpf/soc1/oncpu/cpu1.folded ./output
```

### 场景3: Jira/Event数据快速分析

用于快速生成Jira关联的全量性能报告。

```bash
# 下载jira对应的mcap并解析metrics
ados_tools --mode jira_report --jira_id ADLSVC-62899

# 上传解析报告到云端并更新jira信息
ados_tools --mode jira_report --jira_id ADLSVC-62899 --upload

# 下载并解析event对应的mcap文件
ados_tools --mode jira_report --event_id 2411907
```

### 场景4: 查看已解析的数据

```bash
ados_tools --mode show_data
```

## 输出结果说明

### 输出目录结构

解析结果保存在 `$HOME/perf_analysis/` 目录下:

```
$HOME/perf_analysis/
├── {车号}/
│   └── {时间范围}/
│       ├── metrics/     # metrics分析结果
│       ├── trace/       # trace分析结果
│       └── ebpf/        # ebpf分析结果
└── {event_id}/          # event解析结果
```

### 结果查看方式

解析完成后会自动:
1. 启动本地Python server (默认端口8000)
2. 自动打开浏览器展示结果

**手动访问方式**:
- 本机访问: `http://127.0.0.1:8000`
- 远程访问: `http://<主机IP>:8000`

### 各类型数据展示

**Metrics**: 展示性能指标图表，包括CPU、内存、延迟等关键指标

**Trace**: 提供Perfetto可视化界面，可查看详细的执行轨迹和时间线

**eBPF**: 生成火焰图，展示CPU调用栈和热点函数

## 参数详解

### 云端数据参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--mode` | 解析模式: all/metrics/trace/ebpf/show_data | all |
| `--car_id` | 车辆ID(需输全) | 无 |
| `--time` | 时间范围 "开始时间 结束时间" | 无 |
| `--add` | 指定SOC id (仅ebpf生效) | 无 |

### 本地数据参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--mode` | 解析模式: metrics_local/metrics_local_plot/trace_local/ebpf_local/ebpf_diff | 无 |
| `--input_dir` | 输入record目录 | 无 |
| `--output_dir` | 输出解析数据目录 | 无 |
| `--raw_args` | ebpf解析透传参数(仅ebpf_local生效) | 无 |

### ebpf透传参数

| 参数 | 说明 |
|------|------|
| `--type` | 文件类型: bcc_profile/trigger_record/perf_record |
| `--manifest` | manifest文件路径 |
| `--mapping_file` | kallsyms.txt和proc_maps.txt所在目录 |
| `--add` | soc1或soc2 |
| `-t` | 解析时间范围 |

## 常见问题与注意事项

### 时间范围选择
- 时间范围尽量精确，避免解析时间过长
- 如果不知道准确毫秒，可以输入000
- 云端数据下载和解析时间与时间范围成正比

### 车辆ID格式
- 必须输入完整的车辆ID(例如a014而不是a14)
- ID字母会自动转换为大写

### SOC选择
- 单SOC车型: 使用soc1
- 双SOC车型(BHD): 根据需要选择soc1或soc2，不指定则解析所有SOC

### 浏览器要求
- 默认使用谷歌浏览器打开结果
- 如果没有谷歌浏览器，可手动访问 `http://127.0.0.1:8000`
- 远程访问时使用主机IP地址

### 数据通道要求
本地record文件必须包含以下通道之一:
- `/ados/apprt/metrics` (metrics数据)
- `/ados/apprt/trace2` (trace数据)
- ebpf相关通道 (ebpf数据)

## 工作流程建议

### 性能问题排查流程

1. **确定问题时间和车辆**
   - 获取问题发生的准确时间范围
   - 确认车辆ID

2. **选择数据类型**
   - metrics: 查看整体性能指标
   - trace: 分析具体执行流程
   - ebpf: 定位CPU热点和性能瓶颈

3. **执行解析**
   - 云端数据: 使用 `--mode` + `--car_id` + `--time`
   - 本地数据: 使用 `--mode_local` + `--input_dir`

4. **分析结果**
   - 查看自动打开的浏览器页面
   - 根据问题类型重点关注相应指标

5. **深入分析**
   - 如需对比，使用差分火焰图
   - 如需更详细trace，使用Perfetto界面

### 快速Jira报告生成

1. 获取Jira ID
2. 执行 `ados_tools --mode jira_report --jira_id <ID>`
3. 查看生成的metrics报告
4. 如需上传: `ados_tools --mode jira_report --jira_id <ID> --upload`

## 相关资源

- **手动数据录制**: Recorder工具使用说明
- **工具设计文档**: ados_tools统一命令行工具设计与实现
- **Trace可视化**: MiPilot Trace可视化兼容Perfetto
- **金山云控制台**: https://ks3.console.ksyun.com (查看原始mcap数据)
