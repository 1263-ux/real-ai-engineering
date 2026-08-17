# DESIGN — 顶层设计（ChatGPT 网页版 / 你 填写）

> 文件协议 v2.2。位置：`<项目>/.agent/DESIGN.md`（DSH 从全局模板播种，每项目一份）。本文件是 PLAN 的唯一需求来源：
> - 每次修改本文件 → 递增 `design_version`（如 2026-08-16-01 → -02）→ 旧 PLAN 立即视为过期
> - 只有 `status: approved` 的设计才允许据此出计划并执行

## Metadata

- design_version: 2026-08-16-01
- status: draft          <!-- draft → approved（人工确认后改；-FromDesign 出计划要求 approved 且 design_version 必填，否则退出码 5） -->
- updated_at: 2026-08-16T16:40:00+08:00

## Goal

<!-- 一句话：要解决什么问题、给谁用 -->

## Context

<!-- 背景：现状、相关代码/文件位置、为什么现在做 -->

## Constraints

<!-- 技术栈、预算、时间、平台等硬约束 -->

## Non-goals

<!-- 明确不做的事，给 AI 装刹车。例：
- 不改数据库结构
- 不新增依赖
- 不重构现有模块
-->

## Acceptance Criteria

<!-- 每条一个稳定 ID（AC1/AC2/...），可验证、能跑/能看。Planner 必须原样保留这些 ID，
不得新增、删除或重命名（脚本 -FromDesign 会校验 AC 集合一致）。例：
- AC1: GET /health 返回 200 且 body 为 {"status":"ok"}
- AC2: 现有测试全部通过
-->

## Candidate Approaches

<!-- 每个方案一行：思路 + 优点 + 缺点 -->

## Rejected

<!-- 已否决的方向 + 否决原因，避免重复踩坑 -->

## Decision

<!-- 选定哪个方案、为什么 -->

## Open Questions

<!-- 未决问题；执行前必须澄清的排最前 -->
