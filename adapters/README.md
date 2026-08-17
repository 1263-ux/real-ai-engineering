# adapters

把 portable policy 落到某个 Harness 的 runtime 实现。

- portable 层（`solutions/` 里的 SKILL.md）定义「应该怎样」。
- adapter 提供「在这个 Harness 上怎么硬性保证」。

| adapter | 对应 policy | 内容 |
|---|---|---|
| [dsh](dsh/) | dev-loop | codex-plan.ps1（只读规划 + 原子替换 + 逐 Task/AC 校验）、agent-handoff.md（实现协议）、模板 |
