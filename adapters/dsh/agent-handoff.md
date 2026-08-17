# DSH Runtime Adapter — 文件交接实现协议（协议 v2.2 · 布局 v3）

> 本文件是 `dev-loop` Skill 的 **DSH Runtime Adapter 实现协议**，不是 dev-loop 的通用角色定义。
> 通用角色 / 工件 / 门禁见 `.agents/skills/dev-loop/SKILL.md`；本文件只规定 DSH 如何落地硬保证。

## 角色分工（单执行者原则）

| 角色 | 职责 | 写权限 | 输出 |
|---|---|---|---|
| **Human Owner（你）** | 目标 / 取舍 / 批准 / 终验 | `PLAN.md` 的 status | approved 的 PLAN |
| **Planner Expert**（当前：Codex / claude→DeepSeek） | 顶层设计细化为可执行计划（只读） | **无**（runtime 强制只读） | `PLAN.md` 正文 |
| **Review Expert**（当前：GPT Web） | 独立审查（按需，EXPERT_PACKET） | 无 | VERDICT + findings |
| **DSH Executor（我）** | 读取计划、逐步执行、验证、回报 | 项目文件 + `STATUS.md` | 代码 / STATUS.md |

> **单执行者原则：默认只有 Executor（DSH）修改项目文件。** Planner / Review Expert 永远只读。

## 布局 v3：项目化（工作流全局、状态随项目走）

- **全局定义**：`~/.dsh/workflow/`——本文件、WORKFLOW.md、codex-plan.ps1、templates/、GPT_REVIEW_TEMPLATE.md
- **项目状态**：`<项目>/.agent/`——DESIGN.md / PLAN.md / STATUS.md / 运行日志；随项目走、可进 .gitignore
- **调用**：`codex-plan.ps1 -FromDesign "需求" -Workspace <项目路径>`；`-Planner codex|claude` 选规划器——默认 codex（消耗额度）；
  `-Planner claude` 走本机 claude→DeepSeek（不消耗 Codex）。DSH 永远显式传 -Workspace；切项目 = DSH Web 里切会话，脚本零改动
- **新项目接入**：DSH 从 templates/ 播种 `<项目>/.agent/DESIGN.md`，你填内容后即可走流程

## 交接文件与版本关联

| 文件 | 谁写 | 内容 | 版本字段 |
|---|---|---|---|
| `<项目>/.agent/DESIGN.md` | Owner（可借 Expert） | Goal / Constraints / Non-goals / 验收标准（AC1/AC2/...）/ 方案 | `design_version` + `status` |
| `<项目>/.agent/PLAN.md` | Planner Expert（或 Executor） | Metadata + 分步任务（每步 Status/目标/文件/验收） | `plan_id`（自身唯一）+ `design_version`（来源引用） |
| `<项目>/.agent/STATUS.md` | Executor（DSH） | 当前任务、进度、每步结果、验证 | `plan_id`（引用当前 PLAN）+ `supersedes` |

**三条硬规则：**
1. **改 DESIGN 必须递增 `design_version`**，旧 PLAN 立即作废（不再执行）。
2. **DSH 只执行 `status: approved` 的 PLAN**；执行前核对 `STATUS.plan_id == PLAN.plan_id` 且 `PLAN.design_version == DESIGN.design_version`，不一致就停下问人。`-FromDesign` 出计划是 fail-closed：DESIGN.md 必须存在、`design_version` 必须非空、`status` 必须 approved，否则退出码 5，不生成。
3. **任何失败不得静默**：脚本返回非 0 + 写日志；规划器失败或替换失败时旧 PLAN.md 原样保留（替换无 fallback，失败即失败）。

## 状态边界（消除双状态源）

- **PLAN.status** 只表达授权状态：`draft → approved`（可能 `superseded`）。**不写 executing/done**。
- **执行进度只归 STATUS.state**：`pending → in_progress → done`（异常 `blocked / superseded`）。
- **Per-Task Status**（TODO/IN_PROGRESS/DONE/BLOCKED）是计划内的任务级标记，随执行更新，不等于 PLAN 的授权状态。

## STATUS 初始化 / 重新绑定规则（消除首次执行死锁）

新 PLAN 已 `approved`，且 `PLAN.design_version == DESIGN.design_version`，且 `STATUS.plan_id != PLAN.plan_id` 时：

1. DSH 先看旧 STATUS 的 `state`：
   - 若为 `in_progress` → **不得自动 supersede**：必须停下问人，经人工确认后才能把旧 STATUS 标记为 `superseded`；
   - 否则（pending / done / blocked / superseded）→ 允许重新绑定。
2. 重新绑定：`STATUS.plan_id = PLAN.plan_id`；`state = pending`；`Done = 0/N`；`Current = Task 1`；旧 plan_id 记入 `supersedes`。
3. **绑定这一步不视为执行项目任务**；绑定完成后才做 equality check 并开始执行。

## 标准流程

1. **设计**：需求写进 `DESIGN.md`（或让 Owner 借 Expert 写），填好 `design_version`，验收标准写成 `AC1/AC2/...`，改 `status: approved`。
2. **出计划**（只消耗一次规划器额度）：
   ```powershell
   .\codex-plan.ps1 -FromDesign "按 DESIGN.md 出计划" -Workspace "D:\Projects\<项目>"
   ```
   （日常由 DSH 代跑：你只需说「先规划」，不必碰 PowerShell）
   规划器只读由 runtime 强制（Codex `--sandbox read-only`；Claude `--bare --tools=`），仅本次调用，不改全局配置。
3. **人工 gate**：你审 PLAN.md，把 `status: draft` 改成 `approved`（可以让我代改，但决定权在你）。
4. **执行**：在 DSH 对话里说「按 PLAN.md 执行」——我先按上面"重新绑定规则"初始化/核对 STATUS，再逐步执行并更新 `STATUS.md`。
5. **验证**：结果写进 `STATUS.md` 的 Verification 段；遗留问题写 Open Questions 发回 Planner / Review Expert。

## 计划正文合同

Planner 输出必须按 `### Task N：<标题>` 组织，且**每个 Task 块**含 Status / 目标 / 涉及文件 / 验收标准
四个必填字段（codex-plan.ps1 逐 Task 校验强制）；其余字段（依赖/风险/执行者）由 E2E 验收完整性。
`-FromDesign` 时还校验 DESIGN 的 AC id 集合与 PLAN 引用一致（不得增删改 AC）。

## 注意

- `codex-plan.ps1` v3.1 全局安装在 `~/.dsh/workflow/`，调用必传 `-Workspace`；只在需要出计划时用。
- 规划器只读由 wrapper 的 runtime 参数保证（作用域=单次调用）；**不建议**为此修改全局配置（如 `~/.codex/config.toml` 的 sandbox_mode）。
- 这份流程只依赖磁盘文件，多方不需要任何插件/API 互联。
