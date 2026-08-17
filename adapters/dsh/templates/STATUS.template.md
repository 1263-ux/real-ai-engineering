# STATUS — 执行状态（DSH agent 维护）

> 文件协议 v2.2。位置：`<项目>/.agent/STATUS.md`。DSH 每次开始执行前必须核对：
> 1. PLAN.status == approved，否则停下问人
> 2. STATUS.plan_id == PLAN.plan_id，不一致说明计划已过期
> 3. 新 PLAN 获批后，DSH 允许在正式执行前先将本文件重新绑定到新 plan_id
>    （见 agent-handoff.md「STATUS 初始化 / 重新绑定规则」；该步骤不算执行任务）

## Metadata

- plan_id: plan-20260816-174500123    <!-- 等于当前 PLAN.md 的 plan_id -->
- supersedes:                        <!-- 重新绑定时填旧 plan_id，如 plan-20260816-170000000 -->
- state: pending                     <!-- pending | in_progress | done | blocked | superseded -->
- updated_at: 2026-08-16T16:40:00+08:00

## Progress

- Current: Task 1
- Done: 0/2
- Blocked: none | Task 2（原因）
- Next: Task 1

## Per-Task Results

| Task | Status | Result / Artifact | Acceptance |
|---|---|---|---|
| 1 | DONE | `src/...` | pass |
| 2 | TODO | — | — |

## Verification

<!-- 验收结果直接写这里，不另设 VERIFY.md -->
- unit tests:
- integration tests:
- git diff --check:

## Open Questions

<!-- 需要发回 Codex 或 ChatGPT 澄清的问题 -->
