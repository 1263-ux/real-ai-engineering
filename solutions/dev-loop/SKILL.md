---
name: dev-loop
description: >-
  面向真实开发迭代的 AI 开发循环。人工为 Owner 与关键门禁，
  单执行者保证代码一致性，以工件而非长对话完成跨模型协作，
  按任务风险与稀缺额度按需调用独立专家。适用于需要规划、实现、
  验证、试用和迭代的软件开发任务；高风险 RC/发布/安全审计场景
  另有 references/triad-engineering-closure.md 完整版可升级。
---

# dev-loop — AI 开发循环（宪法 + Playbook）

> **我们规范化开发循环，而不是规范化某个 AI。**
> 以当前 Host Harness 为单一入口；以人工为 Owner 与关键门禁；以单执行者保证代码一致性；
> 以工件而非长对话完成跨模型协作；按任务风险与稀缺额度按需调用独立专家；
> 开发失败时回到正确阶段，而不是让 Agent 无限互审和打补丁。

## 核心思想（6 条）

1. **人是 Owner，不是调度器** — 人决定目标、方案、风险、是否继续和最终体验；不决定模型、Provider 或下一条命令。
2. **实现者不能证明自己正确** — 实现者不审批自己的实现；高风险独立检查按 Playbook 触发。
3. **工件优先于长对话** — 交接 Goal / Constraints / PLAN / Diff / Test Result / Blocker；独立上下文不继承长聊天。
4. **证据高于共识** — 真实运行 > 测试 > Diff/源码 > 工件 > Agent 判断 > Agent 共识。
5. **失败必须有回路** — 明确为什么回到 DESIGN、PLAN、IMPLEMENT 或 BLOCKED，禁止无差别补丁。
6. **够用即停** — 证据满足后停止升级、重复检查和额外审计。

## 触发条件

以下目标必须先装载本 Skill，并播种 `.agent/CURRENT_STATE`（状态 + 下一步）：

- 多文件改动、跨文件重构；
- 多步骤 git、分支、PR、发布、review、同步；
- 工具链、运行时、环境迁移；
- 需要他人验收或跨会话继续的结果。

单步查询、单文件小改、一次性命令可不走完整循环，但交付时留一句结论。

## Constitution（十条）

1. Human owns goals and gates.
2. One writer at a time.
3. Artifacts over conversations.
4. Evidence over consensus.
5. Fresh context for independent review.
6. Cheap models do token-heavy work; scarce models handle high-value judgment.
7. Escalate only when expected value justifies it.
8. Repeated failure triggers rethink, not more patching.
9. New experts do not create new workflows.
10. Stop when acceptance is satisfied.

## 状态机与最小工件

```text
DESIGN → PLAN → IMPLEMENT → VERIFY → TRIAL → DONE
异常：BLOCKED / RETHINK
```

- 多步任务：开始和每轮结束更新一句话 `CURRENT_STATE`；完成留最小 `RESULT`（结论 + 残留）。
- 复杂/高风险任务才落完整 DESIGN / PLAN / RESULT / STATUS；小任务不为了展示流程创建工件。

## Playbook（先分级，再应用修饰器）

### 基础等级

| 等级 | 适用任务 | 主路径 |
|---|---|---|
| **L0** | 一行修改、文案、CSS、解释 | 改 → 快速验证 → 汇报 |
| **L1** | 单模块 bug、一两个文件、无运行态影响 | 简短计划 → 改 → 测试 → 汇报 |
| **L2** | 运行态、跨模块、插件、Host/Client、配置写回、服务环境 | 根因 → 修改 → 测试 → 按规则检查 → 受控验证 |
| **L3** | commit、push、PR、发布、外部消息 | 必要验证 → Owner 对具体动作授权 → 交付 |

### 路径修饰器

- **复杂跨文件/有取舍**：需要 DESIGN → PLAN → G2 → IMPLEMENT → VERIFY → TRIAL。
- **高风险**：认证、数据库、协议、权限、真实数据、服务重启、路径安全、发布包、外部发布、高风险重构；按“独立检查规则”判断，不叠加第二套完整流程。
- **架构不确定**：DESIGN 先行，必要时 G1/G3。
- **运维/发布**：PLAN 可为清单；验证以真实运行结果、diff、git 状态为准。

**修饰器只改变必要门禁，不叠加完整流程；同一任务选择最高风险路径，不重复套用多个流程。风险优先于文件数量。**

### 独立检查规则（唯一规范来源）

- 目的：防止自审，不是制造流程税；必须 fresh context，默认便宜/白嫖模型，最多一次。
- 触发：易泄露密钥或个人数据、改真实配置或数据、认证、数据库、协议、权限、服务重启、路径安全、发布包、外部发布、高风险重构、用户明确要求 review。
- L0/L1 默认不拉 reviewer；L2/L3 按触发场景判断。测试与本地准备并行，不得阻塞 IMPLEMENT/本地 VERIFY。
- 用户说“直接 PR / 继续 / 授权 / 快”时，停止可选 review、重复测试和低价值审计；但不能覆盖已发现的密钥/个人数据泄露、真实配置或数据损坏、权限越界、授权缺失等硬阻塞。
- 只有三种情况可让子 agent 阻塞主线：确认安全泄露、确认真实数据破坏、下一步确实依赖其协议/API 结论；否则后台运行，晚到 blocker 另补 fix commit。

### 停止与交付规则

- **根因先行**：先给根因再给流程；根因明确后立即执行，不重复确认已知事实。
- **时间盒**：根因判断 ≤15 分钟、可运行修复 ≤30 分钟；超时停止试错并输出：事实 / 假设 / 已排除 / 阻塞 / 所需决策。
- **证据够了就停**：已通过检查不重跑；针对性测试 + 必要的 build/pack/扫描 + 一次状态确认即交付。
- **已授权 PR 追加小修**：局部 diff → 针对性测试 → 敏感扫描 → commit → push → 一次状态确认；不重套 L3、不重跑冻结测试、不重新梳理 PR 全文。
- **高危运行态动作**：计划阶段授权，授权包含动作、目标服务、影响范围、回滚方式、是否允许改真实数据。

## Failure Routing

| 类型 | 回到 |
|---|---|
| Implementation Failure | IMPLEMENT |
| Plan Failure | PLAN |
| Design Failure | DESIGN |
| Requirement Failure | Owner 重新判断 |
| 环境/外部失败（网络、代理、第三方、配额） | BLOCKED，不计入逻辑 RETHINK |
| 同类逻辑失败连续 2 次 | RETHINK，回根因 |

环境失败按检查代理/端口/环境 → 换源 → 有限退避重试 → BLOCKED 处理。路径编组问题按 adapter troubleshooting 处理，不写成平台通用硬规则。

## Artifact Contract

- `DESIGN`：Goal / Constraints / Non-goals / Key Decisions / Acceptance。
- `PLAN`：What / Where / Order / Risks / Verification；按风险点、所有权和可独立验证边界拆分。
- `RESULT`：Changed / Tests / Runtime result / Known issues。
- `EXPERT_PACKET`：Goal / Constraints / Evidence / Proposal / Questions / Expected output。
- `.agent/` 是状态交接，不是展示性产物；每轮最多更新一次，状态滞后时下轮先同步。

## 人类门禁

- **G1** 方向变化；**G2** 高风险执行；**G3** 成本/外部 Expert；**G4** 真实体验。
- 实质性范围扩张（显著扩大 blast radius、权限边界、数据影响或发布范围）时重新确认目标与执行风险；不要求所有跨系统改动重建全套工件。
- FROZEN 只在条件不变时有效；源码/依赖、运行环境、验收数据、核心闭环或用户报告与证据矛盾时失效。

## Expert 与资源

- 新增 Expert 不新增流程；稀缺升级按价值判断，默认最多一次，不默认前后双审。
- 模型能力、价格、额度与 Provider 是用户资产，不写入方法论；见 `references/model-resources.md`。密钥不入库。
- DSH 负责编排；Codex/其他执行器按资源表承担实现；独立检查按“独立检查规则”选择。

## 证据与临时补丁

- 文件存在不等于能力接入；集成脚本不等于 E2E；缓存/Fixture 标注 `SIMULATED` / `REPLAYED`。
- 临时/安装态补丁至少记录：临时原因、验证方式、回退或上游跟踪；禁止无记录地当长期修复。
- FROZEN 是条件性结论，不是永久豁免。

## 机制层

- portable policy 与 Runtime enforcement 分离；当前 DSH adapter 负责原子替换、单 writer、门禁和 Planner 接入。
- DSH 具体链路、Windows troubleshooting、settings 暴露链路见 `adapters/dsh/` references；本 Skill 不复制平台细节。
