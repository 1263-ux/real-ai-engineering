# acceptance-drift

真实漂移事故的回归样本：DESIGN 只有 3 条验收（AC1/AC2/AC3），Planner 生成的 PLAN 却声称「4 条验收标准」，且人类终验也签了过去。

- **发生了什么**：`DESIGN.md` 3 AC → `PLAN.md` 幻觉成「4 条 AC」→ `STATUS.md` 又回到 3 → 人类门禁 CLOSED。
- **结论**：模型没有报错，工件之间却发生语义漂移；Human Gate 本身 ≠ 可靠性。
- **长出的规则**：DESIGN 的 AC 必须带稳定 ID（AC1/AC2/...），Planner 不得增删改；脚本 `-FromDesign` 校验 AC 集合一致（missing / extra → exit 2）。
- **文件**：`DESIGN.md` / `PLAN.md` / `STATUS.md`（原始漂移证据，仅隐去本机绝对路径，其余原样保留）。
