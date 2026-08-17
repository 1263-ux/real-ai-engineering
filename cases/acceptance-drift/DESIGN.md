# DESIGN — 三方工作流仓库 README（e2e 仿真验收载体）

## Metadata

- design_version: 2026-08-16-01
- status: approved
- updated_at: 2026-08-16T20:30:00+08:00

## Goal

给三方工作流（ChatGPT 网页版 + Codex Plus / 本地 Claude→DeepSeek + DSH）写一份仓库门面 `README.md`，
让第一次看到这个仓库的人 3 分钟内理解：它是什么、三个入口怎么用、文件放哪里。

## Context

- 仓库根目录：`three --workflow`
- 现有文档：全局定义在 `~/.dsh/workflow/`（WORKFLOW.md 用户版、agent-handoff.md 协议、templates/、codex-plan.ps1）；仓库内只有 `agent-workflow-v2/` 源码
- README 定位：仓库门面，指路为主，不重复文档全文

## Constraints

- 中文写作，Markdown 格式
- 只新增一个文件 `README.md`，不改任何现有文件
- 不引入构建工具或依赖

## Non-goals

- 不复制 WORKFLOW.md / agent-handoff.md 的全文
- 不做文档站点、不做多语言版本

## Acceptance Criteria

- [ ] 仓库根目录出现 `README.md`
- [ ] 内容包含：一句话定位；三入口用法（日常 / 先规划 / 高价值把关）；目录与文档导航（全局 vs 项目 `.agent/`）；e2e 快速开始（含 `-Planner claude` 无额度路径）
- [ ] 除新增 README.md 外，仓库现有文件零改动

## Candidate Approaches

1. 单文件 README + 指路（推荐：内容体量足够，避免文档碎片化）
2. README + docs/ 子目录（过重，当前内容撑不起多文档）

## Rejected

- docs/ 目录结构：体量不够，维护成本高

## Decision

单文件 README，指路型。

## Open Questions

无
