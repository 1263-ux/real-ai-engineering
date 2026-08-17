# GPT Web profile — 基于 EXPERT_PACKET 的审查模板

> 本文件是 `EXPERT_PACKET`（**唯一 Expert 输入合同**，见 `.agents/skills/dev-loop/templates/EXPERT_PACKET.template.md`）
> 的 **GPT 网页版 profile**，不再重新定义 Goal/Evidence/Constraints 整套结构。
> 用法：Host Executor 按 EXPERT_PACKET 组装内容后，套用下面的问题与回执格式，拖进 ChatGPT 网页版一次审查，
> 把 VERDICT 段贴回。只允许一个来回；传有界工件，不开长聊天。

## Recommended questions

1. 当前设计/实现最大的结构性风险是什么？
2. 有无错误假设或漏掉的边界条件？
3. 是否存在必须在执行前修改的 blocker？

## Expected response

VERDICT: APPROVE | REVISE | BLOCK

BLOCKERS:
...

REQUIRED_CHANGES:
...

OPTIONAL:
...
