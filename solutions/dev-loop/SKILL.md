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

## 核心思想（6 条，不随模型变化）

1. **人是 Owner，不是调度器** — 人决定：要什么 / 方案能不能接受 / 风险值不值 / 要不要继续 / 最终体验行不行。人**不**决定：用哪个模型、哪个 Provider、哪条 Pipeline、下一步跑什么命令。
2. **实现者不能证明自己正确** — 实现者不审批自己的实现。简单任务「测试 + 用户验收」即够；高风险才升级独立 Expert。
3. **跨角色交接以工件为准，不转交长聊天** — 交接 bounded artifact（Goal / Constraints / PLAN / Diff / Test Result / Blocker），不交接几十轮聊天；独立 Expert 默认 fresh context，同一 Executor 可保留当前任务上下文。
4. **证据高于模型共识** — 真实试用/运行 > 测试结果 > Diff/源码 > 明确工件 > Agent 判断 > Agent 共识。三票赞成没有测试通过值钱，不搞投票。
5. **每一轮必须知道「为什么回去」** — 失败必须分类路由（见 Failure Routing），禁止无差别「再改一次」。
6. **够用即停** — required evidence 满足即停止升级 Provider、重复抓取和额外审计，防止膨胀成「多方会审 2.0」。

## Constitution（十条，不可违反）

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

## 状态机（工作模式，不是仪式）

```
DESIGN → PLAN → IMPLEMENT → VERIFY → TRIAL → DONE
异常：BLOCKED（等人/外部） / RETHINK（停止补丁，回根因）
```

- 简单任务只在心里走状态，不产工件；复杂/高风险任务才落 `.agent/` 工件。
- 普通任务完全不展示状态；状态是 Agent 的工作模式，不是给用户看的仪表盘。

## Playbook（怎么选路）

| 任务 | 路径 | 门禁 |
|---|---|---|
| 简单（CRUD/文案/小 bug） | IMPLEMENT → VERIFY → 结果交付 → DONE | 无 |
| 复杂（跨文件/有取舍） | DESIGN → PLAN → **G2** → IMPLEMENT → VERIFY → TRIAL → DONE | G2 |
| 高风险（认证/DB/协议/重构/发布） | 复杂路径 + 独立 Expert 审查 | G2 + G3 |
| 架构级/方向拿不准 | DESIGN 先行 + Expert 审查 | G1 + G3 |

## 阶段职责

- **DESIGN** — 我们到底应该怎么做？可由 Host Executor / Planner Expert / Review Expert 参与；**人确认方向（G1）**。产 `DESIGN`。
- **PLAN** — 这次具体改什么？通常 Host Executor draft，复杂时 Expert critique/plan。产 `PLAN`。
- **IMPLEMENT** — 只有一个 Writer（当前 Executor），其他人只读；只改当前任务，不顺手重构。产生代码变更。
- **VERIFY** — 优先 tests / build / lint / 运行 / diff，**不是先叫另一个模型**；`RESULT` 在此定稿（执行阶段持续更新的工件，VERIFY 后才完整）。
- **TRIAL** — 真实拿来用：测试通过 ≠ 体验正确。Executor 交付「怎么试」清单，人的体验 = 最终验收（G4）。
- **DONE** — 验收标准满足，证据入档；已通过路径冻结（FROZEN）。

## Failure Routing（为什么回去，回到哪）

| 失败类型 | 判定 | 回到 |
|---|---|---|
| Implementation Failure | 代码没按方案做 | IMPLEMENT |
| Plan Failure | 计划漏了东西 / 顺序错 | PLAN |
| Design Failure | 架构/方案假设错了 | DESIGN |
| Requirement Failure | 目标/范围本身有问题 | 人工（Owner）重新判断 |
| **RETHINK** | **同类失败连续 2 次** | 停止补丁 → 根因 → 重写 DESIGN/决策 |

- 连续两次同类失败 = 强制 RETHINK，禁止继续打补丁（继承旧 Skill 的刹车）。
- 回 DESIGN / 需求 = 变更必须记录（递增 `design_version`，旧 PLAN 立即作废）。
- 回 PLAN / IMPLEMENT = 修复后补回归证据，不影响已冻结部分。

## Artifact Contract（角色之间交接什么）

- **Primary artifacts（4）**：DESIGN / PLAN / RESULT / EXPERT_PACKET
- **Checkpoint（1）**：CURRENT_STATE（循环快照，非主工件）
- **Machine state（1）**：STATUS.md（机器内部状态，非交流内容）

| 工件 | 回答 | 内容 |
|---|---|---|
| `DESIGN` | 怎么做 | Goal / Constraints / Non-goals / Key Decisions / Acceptance |
| `PLAN` | 改什么 | What changes / Where / Order / Risks / Verification |
| `RESULT` | 结果如何 | Changed / Tests / Runtime result / Known issues |
| `EXPERT_PACKET` | 请专家看什么 | Goal / Constraints / Evidence / Current proposal / Exact questions / Expected output |

- `CURRENT_STATE`：每轮循环结束的压缩快照（≤200 字，模板见 templates/），新轮次从这里开始，旧聊天封存。
- 位置：`<项目>/.agent/`（DESIGN.md / PLAN.md / STATUS.md / RESULT.md）；EXPERT_PACKET 按需生成。

## Expert 规范（新增专家不新增流程）

```
Expert { capability, invocation, input_contract, output_contract }
```

| Expert | capability | invocation | input | output |
|---|---|---|---|---|
| Codex | repo planning / review | 自动 CLI（codex-plan.ps1） | DESIGN + Task Request | PLAN 正文 |
| GPT Web | 架构 / 独立审查 | 手动网页 | EXPERT_PACKET | VERDICT + critical findings |
| 其他（Gemini 等） | 按需定义 | 手动/API | 同一套 Packet | 同构输出 |

- 新增 Expert = 填一行表格，**不新增流程、不新增状态、不新增工件类型**。
- **默认一次任务最多一次稀缺 Expert 升级**，放在最可能改变结果的节点：架构不确定 → DESIGN/PLAN 时审；实现风险高但方案明确 → VERIFY 后 Review。只有出现新的高风险证据才追加第二次，**不默认前后双审**。

## 人类门禁（只有 4 个）

- **G1 方向变化** — 是否接受新的设计方向？
- **G2 高风险执行** — 是否执行可能大范围改变项目的 PLAN？
- **G3 成本/外部 Expert** — 是否值得消耗 Codex/GPT/其他稀缺额度？
- **G4 真实体验** — 这个结果是不是你真正想要的？

- G1–G3 是**显式门禁**；G4 是**最终接受原则**，不要求每次显式弹窗——简单任务交付后用户继续使用即视为验收；复杂/体验型任务才显式走 TRIAL/G4。

除此之外（修哪个 import / 跑哪个测试 / 用什么命令 / 怎么 fallback）一律不烦人。

## 证据与反幻觉（继承旧 Skill 的核心刹车）

- 报告不是证据；实物为准。
- 文件存在 ≠ 能力接入；集成脚本 ≠ 产品 E2E；缓存/Fixture 只能标 `SIMULATED / REPLAYED`。
- 反幻觉触发器：模糊标识（"latest" / "约 55 个测试"）/ 历史产物复用 / 自写脚本冒充正式入口 / 绿色对勾掩盖 partial。
- 冻结就是冻结：已通过且 FROZEN 的路径不重开、不重复全量验证（除非数据损坏、凭据泄漏、核心闭环失效）。
- Bug ≠ 当前阻塞：先分类，非阻塞进 backlog，不移动已通过 Gate 的终点。

## 机制层（portable policy ↔ runtime enforcement）

> 本 Skill 的开发循环与 Artifact Contract 是 **portable policy**；硬门禁、原子替换和外部 Expert
> invocation 由宿主 Runtime Adapter 提供。若当前 Harness 不具备对应机制，不得假装这些硬保证已执行。

- **DSH adapter**（当前 Runtime 的实际执行者）：
  - 单执行者 / 原子替换 / 旧 PLAN 不因失败损坏 / fail-closed 门禁 → `~/.dsh/workflow/agent-handoff.md`
  - PLAN 生成（可选 Planner adapter）→ `~/.dsh/workflow/codex-plan.ps1`
  - 播种模板 → `~/.dsh/workflow/templates/`（DESIGN / PLAN / STATUS）
- **本 Skill 自带资源**（相对 Skill-root，跨 Harness）：`templates/`（RESULT / EXPERT_PACKET / CURRENT_STATE）、`references/`（高风险完整版）
- 专家/Provider 的具体额度与调用方式不是本 Skill 的稳定合同：**固定能力角色，不固定谁现在免费**。
