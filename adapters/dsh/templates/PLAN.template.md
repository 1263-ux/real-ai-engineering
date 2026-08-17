# PLAN — 分步执行计划

> 文件协议 v2.2。位置：`<项目>/.agent/PLAN.md`。
> - 生成：`.\codex-plan.ps1 -FromDesign "一句话目标" -Workspace <项目路径>`（Codex 只读生成，Metadata 由脚本注入）
> - 执行门槛：`status` 必须是 `approved`，且 `design_version` 等于当前 DESIGN.md 的版本
> - 授权状态：`status` 只有 `draft → approved`；执行进度由 `STATUS.state` 维护（pending/in_progress/done/blocked），**不写进 PLAN**

## Metadata

- plan_id: plan-20260816-174500        <!-- 本次计划唯一 ID，由脚本生成（不等于 design_version） -->
- design_version: 2026-08-16-01        <!-- 引用来源 DESIGN 的版本 -->
- design_status: approved
- generated_by: codex / 人工
- generated_at: 2026-08-16T16:40:00+08:00
- status: draft
- approved_at:
- approved_by:

## Tasks

### Task 1：<标题>

- Status: TODO        <!-- TODO → IN_PROGRESS → DONE；失败/受阻 → BLOCKED + 原因 -->
- 目标：
- 涉及文件：
- 依赖：Task N / 无
- 风险：
- 执行者：DSH agent / 人工
- 验收标准：

### Task 2：<标题>

<!-- 同上格式，每步一个 Task 小节 -->
