# FROZEN — 已冻结基线

## dev-loop v3.2（2026-08-18 冻结）

> 基线来源：v3.1 → 真实会话复盘（零装载 / 零工件 / 环境失败误路由）→
> `solutions/dev-loop/v3.2-change-design.md`（G1 批准后实施并冻结）。

### v3.2 相对 v3.1 的变更

- **C1 触发条件**：新增「触发条件」段——多文件改动 / 多步骤 git / 发布 / review / 工具链迁移 / 需验收的目标，第一步必须装载本 Skill 并播种 `.agent/CURRENT_STATE`（一句话即可）；违规信号 = 无 CURRENT_STATE。
- **C2 运维轻路径**：Playbook 新增「运维/发布」行——`PLAN(清单) → G2(大范围时) → 执行 → RESULT`，免 DESIGN、免形式化 AC；验证 = 真实运行结果 / diff / git 状态。
- **C3 环境失败归类**：Failure Routing 新增「环境/外部失败（网络/代理/第三方 500/认证/配额/服务抽风）→ BLOCKED」——独立计数，不触发 RETHINK；固定排障序：查代理/端口/环境 → 换源/镜像 → 退避重试（设上限）→ BLOCKED 上报。
- **C4 工件门槛**：所有任务最低一句话级工件——多步任务播种并更新 `.agent/CURRENT_STATE`（最小一行：状态 + 下一步），完成留最小 `RESULT`（结论 + 残留）。
- **C5 review 强制**：高风险 review 必须至少一次独立 Expert（EXPERT_PACKET → fresh context，实现者自审不计数），与「默认最多一次稀缺升级」构成上下限。

### 冻结规则

- 已冻结路径不重开、不重复全量验证（除非数据损坏 / 凭据泄漏 / 核心闭环失效）。
- 后续迭代：先出变更设计（DESIGN）→ 人工 G1 门禁 → 通过后冻结基线升至下一版本。
