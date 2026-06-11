---
name: update-std-md
description: |
  管理项目的 .claude/ 文档结构，支持初始化、更新、新增 feature。
  当用户输入 /update-std-md 或 /update-std-md 加上项目路径时触发。
  无参数时会交互式询问项目路径和操作类型（初始化/更新/新增 feature）。
  也响应初始化项目文档/更新项目规范/新增 feature/管理 .claude 目录等指令。
---

# 项目文档管理技能

本技能通过 `/update-std-md` 命令管理项目的 `.claude/` 文档结构，支持**初始化**、**更新**、**新增 feature** 三种操作。

## 使用方法

### 方式一：带参数（自动检测）

```
/update-std-md <项目路径>
```

系统根据 `.claude/` 是否存在自动选择**初始化**或**更新**。

### 方式二：无参数（交互式）

```
/update-std-md
```

系统依次询问：
1. 📁 **项目路径** - 请用户输入要处理的项目目录
2. 🎯 **操作类型** - 选项：
   - **初始化** - 创建新的 .claude/ 目录结构
   - **更新** - 同步现有文档与项目变更
   - **新增 feature** - 创建新的 Feature 设计文档

## 目录结构

```
.claude/
├── CLAUDE.md              # 主入口
├── rules/                 # 自动加载的规范文档
│   ├── ARCHITECTURE.md   # 架构
│   ├── TECH_STACK.md     # 技术栈
│   ├── CODE_PATTERNS.md  # 代码规范
│   └── DECISION_LOG.md   # 决策记录
└── features/              # Feature 设计文档
    ├── FEATURES.md        # Feature 状态汇总
    └── YYYY-MM-feature-name/   # 单个 Feature 目录
        ├── DESIGN.md      # 设计文档
        ├── TASKS.md       # 任务清单
        └── NOTES.md       # 会议/问题记录
```

---

## 交互流程（无参数时）

```
用户: /update-std-md

Claude: 📁 请输入项目路径:
用户: /home/mi/my-project

Claude: 🎯 请选择操作:
        1. 初始化 - 创建 .claude/ 文档结构
        2. 更新 - 同步项目变更
        3. 新增 feature - 创建 Feature 设计文档
用户: 3

Claude: ✏️ 请输入 feature 名称:
用户: user-auth

Claude: 📝 请输入 feature 描述（可选）:
用户: 用户认证系统，支持 JWT 和 OAuth

[执行创建 feature...]
```

---

## 三种操作模式

### 模式一：初始化

**触发条件**:
- 用户选择"初始化"
- 或 `.claude/` 目录不存在

**步骤**:
1. 分析项目（类型、技术栈、模块）
2. 创建 `.claude/rules/` 目录
3. 创建 `.claude/features/` 目录
4. 生成所有初始文档

**生成文档**:
- **CLAUDE.md**: 项目概述 + 目录结构说明 + 开发流程 + 开发规范
- **rules/ARCHITECTURE.md**: 系统架构、核心模块、数据流
- **rules/TECH_STACK.md**: 编程语言、框架/库、工具链
- **rules/CODE_PATTERNS.md**: 代码组织、命名规范、编码规范
- **rules/DECISION_LOG.md**: 空白（供后续追加）
- **features/FEATURES.md**: Feature 状态汇总表

---

### 模式二：更新

**触发条件**:
- 用户选择"更新"
- 或 `.claude/` 目录已存在

**步骤**:
1. 读取现有 `rules/*.md` 内容
2. 重新分析项目（识别新增/变更）
3. 智能更新文档（保留用户手动编辑内容）
4. 在 DECISION_LOG.md **顶部追加**变更记录

**更新规则**:
- **客观事实自动更新**: 新文件、新依赖、新模块
- **主观描述保留**: 用户原创的设计说明、注释

**追加 DECISION_LOG.md 格式**:
```markdown
## YYYY-MM-DD

- 更新 ARCHITECTURE: 新增 xxx 模块
- 更新 TECH_STACK: 引入 xxx 依赖
- 更新 CODE_PATTERNS: 新增 xxx 规范
```

---

### 模式三：新增 feature

**触发条件**:
- 用户选择"新增 feature"

**步骤**:
1. **检查 .claude/ 是否存在**
   - 不存在 → 提示先执行初始化 → 询问是否现在初始化
2. **询问 feature 信息**:
   - Feature 名称（英文简写，如 `user-auth`）
   - Feature 描述（一句话说明，可选）
3. **创建 feature 目录**:
   - 格式: `.claude/features/YYYY-MM-<feature-name>/`
   - YYYY-MM 必须使用系统当前真实年月（非固定值）
   - 例如执行日期为 2026-03-17，则创建 `.claude/features/2026-03-user-auth/`
4. **生成 feature 文档**:
   - **DESIGN.md**: 设计文档模板
   - **TASKS.md**: 任务清单模板
   - **NOTES.md**: 空白（供记录会议/问题）
5. **登记到 FEATURES.md**:
   - 在表格中添加新行，状态为 🚧 进行中

**DESIGN.md 模板**:
```markdown
# Feature: [名称]

## 背景
<!-- 为什么需要这个 feature -->

## 目标
<!-- 要达成什么目标 -->

## 方案设计
<!-- 技术方案、架构图 -->

## 接口/API
<!-- 对外提供的接口 -->

## 依赖
<!-- 依赖的其他模块/Feature -->

## 风险与考虑
<!-- 潜在问题和应对 -->
```

**TASKS.md 模板**:
```markdown
# Feature: [名称] - 任务清单

## 待办
- [ ] 任务1
- [ ] 任务2

## 进行中
- [ ] 任务3

## 已完成
- [x] 任务0

## 阻塞
- 问题描述 → 解决方案/负责人
```

---

## CLAUDE.md 模板内容

```markdown
# [项目名称]

## 项目概述
<!-- 自动生成：项目类型、主要功能 -->

## .claude 目录结构

```
.claude/
├── CLAUDE.md           # 主入口
├── rules/              # 规范文档（自动加载）
│   ├── ARCHITECTURE.md
│   ├── TECH_STACK.md
│   ├── CODE_PATTERNS.md
│   └── DECISION_LOG.md
└── features/
    ├── FEATURES.md           # Feature 状态汇总
    └── YYYY-MM-feature-name/
        ├── DESIGN.md        # 设计文档
        ├── TASKS.md         # 任务清单
        └── NOTES.md         # 会议/问题记录
```

## 开发流程

1. **查阅规范**: 读取 `rules/*.md` 了解架构和规范
2. **创建 Feature**: 在 `features/` 下新建目录，登记到 FEATURES.md
3. **实现**: 按 TASKS.md 执行，更新 FEATURES.md 状态
4. **完成**: 标记 FEATURES.md 状态为已完成

## 开发规范

- 架构变更 → 更新 ARCHITECTURE.md
- 技术栈变更 → 更新 TECH_STACK.md
- 代码规范变更 → 更新 CODE_PATTERNS.md
- 重要决策 → 在 DECISION_LOG.md **顶部追加**记录
- 新建 Feature → 创建 `features/YYYY-MM-name/` 目录
```

---

## 项目分析指南

| 识别文件 | 判断依据 |
|---------|---------|
| package.json | Node.js |
| requirements.txt, pyproject.toml | Python |
| go.mod | Go |
| Cargo.toml | Rust |
| pom.xml, build.gradle | Java |
| CMakeLists.txt | C/C++ |
| .v, .sv 文件 | Verilog/硬件 |

---

## 输出示例

**初始化**:
```
🔧 初始化模式

✓ 已创建 .claude/CLAUDE.md
✓ 已创建 .claude/rules/ARCHITECTURE.md
✓ 已创建 .claude/rules/TECH_STACK.md
✓ 已创建 .claude/rules/CODE_PATTERNS.md
✓ 已创建 .claude/rules/DECISION_LOG.md
✓ 已创建 .claude/features/FEATURES.md

项目: Python/Flask | 模块: api/, models/, utils/
```

**更新**:
```
🔄 更新模式

△ 已更新 .claude/rules/ARCHITECTURE.md (+auth模块)
△ 已更新 .claude/rules/TECH_STACK.md (+Redis)
△ 已追加 .claude/rules/DECISION_LOG.md
```

**新增 feature**:
```
➕ 新增 Feature 模式

✓ 已创建 .claude/features/2026-03-user-auth/DESIGN.md
✓ 已创建 .claude/features/2026-03-user-auth/TASKS.md
✓ 已创建 .claude/features/2026-03-user-auth/NOTES.md
✓ 已登记到 FEATURES.md (状态: 🚧 进行中)
```
