# dev-loop 默认触发钩子设计（DSH adapter）

> 状态：**DRAFT — 待 G1 审**
> 目标：让 dev-loop 成为 DSH 中开发任务的**默认动作**，不依赖 agent 自觉装载（本轮会话已证明"靠自觉"失效）。
> 相关基线：dev-loop v3.2.2（触发条件 C1 / 资源组配 C6 / 独立检查 C5）。

## Goal

开发任务在 DSH 中自动走 dev-loop：先研究（DESIGN，可一句话）→ 规划（PLAN，清单级）→ 执行（IMPLEMENT）→ 独立检查（review，便宜档）→ 对齐（G1/G4 + AC）→ RESULT；多步任务第一步自动播种 `.agent/CURRENT_STATE`。

## 机制事实（cordis_inspect 实地查证，非猜测）

| 事件 | 模式 | 可用性 |
|---|---|---|
| `system-prompt/assemble` | waterfall | **对已注册完整提示词段的会话无效**——complete section 在 waterfall 后被恢复，监听器不能加/改该作用域的系统提示词。**不能**用它给现有会话注入默认段 |
| `agent/pre-step` | waterfall | **可用**——可"Reject a proposed step or replace the messages that enter it"。真实执行钩子：注入播种提醒 |
| `agent/inbox/inserted` | emit | 可观察任务开始（记录），不能注入 |
| `persona`（`@deepseek-ai/dsh-persona`） | 配置行 | 系统提示词载体，`config.text`。patch 是持久默认层，但 text 为**整段替换**，需先读现有文本再追加 |
| `cordis.patch.yml` | 持久层 | `profiles/web/` 下，web 会话默认层；重启存活 |

结论：**L1（持久默认）只能走 persona/instructions 配置 patch；L2（执行强制）走 `agent/pre-step` 钩子。**

## 设计

### L1 默认工作流进系统提示词（持久，所有 web 会话）

- **方式**：`profiles/web/cordis.patch.yml` patch `persona` 行（或 `agent-instructions` 行，若 bundle 中存在），**追加**以下紧凑段（约 250 字，不重复技能全文）：

```
## 默认开发工作流（dev-loop）
- 开发任务默认流程：研究(DESIGN，可一句话) → 规划(PLAN，清单级) → 执行(IMPLEMENT) → 独立检查(review，便宜档) → 对齐(G1/G4 + AC) → RESULT。
- 多步开发任务第一步：装载 skill dev-loop 并播种 .agent/CURRENT_STATE（一行：状态 + 下一步）。
- 资源组配：实现用 Codex Pro 主力；独立检查用 codex-auto-review / 智谱白嫖；DSH 只编排；deepseek 兜底。
- 失败分类：环境/网络失败 → BLOCKED（不进 RETHINK）；同类逻辑失败 2 次 → RETHINK。
```

- **风险与对策**：`persona.config.text` 是整段替换。实现时必须先读当前有效 persona 文本（含 bundle 层），以"现有文本 + 追加段"写入；或走 `agent-instructions` 行（若为追加语义）。**禁止盲写覆盖。**

### L2 执行钩子（`agent/pre-step`，动态插件 Phase 1）

- **触发检测**：进入该步的用户消息含触发词（继承 v3.2.2 C1 八类）：`多文件 / 跨文件 / 重构 / git / 分支 / PR / 发布 / review / 同步 / 迁移 / 工具链 / 验收`。
- **动作**：若检测到开发任务特征 **且** 该任务消息未被提醒过（内存去重，按消息 id）→ 在 step 消息前注入一条 system 提醒（一次性）：
  - `[dev-loop] 开发任务默认流程：先装载 skill dev-loop 并播种 .agent/CURRENT_STATE（一行：状态+下一步）。`
- **不阻断**：只提醒，不拒绝执行（强制阻断 = 未来可选，需 G1 确认）。
- **零打扰**：非开发任务（查询 / 单步小改 / 闲聊）不注入。

### 落点与阶段

| 阶段 | 内容 | 持久性 |
|---|---|---|
| Phase 1 | 动态插件（host-only）实现 L2，本会话验证 | 进程级 |
| Phase 2 | L1 patch 进 `cordis.patch.yml` | 重启存活 |
| Phase 3（可选） | L2 插件代码沉淀为 patch 插件行 | 重启存活 |

## Acceptance（稳定 ID）

- **AC1** L1 生效后新会话系统提示词含「默认开发工作流（dev-loop）」段。
- **AC2** 开发任务（命中触发词）第一步收到播种提醒，且仅一次。
- **AC3** 非开发任务零提醒注入。
- **AC4** persona 现有文本不被覆盖（追加语义，可 diff 验证）。
- **AC5** 可回滚：插件 stop/undefine、patch 可撤销，无残留。
- **AC6** 触发词在开发语境才激活（如 "review" 出现在提交信息语境时不误触发）。

## 待 G1 确认

1. **L1 注入位置**：patch `persona`（需先读现有文本）还是 `agent-instructions`（若 bundle 有追加语义行）？实现时先探测 bundle。
2. **L2 强制程度**：仅提醒（默认）还是"未播种即阻断步骤"（更强，但打断流畅度）？
3. **触发词清单**：当前 8 类是否够用？会不会误伤日常对话？
4. **Phase 1** 是否先跑动态插件验证 L2，再动 L1 持久 patch？

## 实现记录（2026-08-18，v1 已落地）

- **机制修正**：L1 不走 `cordis.patch.yml` persona patch——实测宿主服务 `systemPrompt.section()`（`{name, order, text}`）即可在会话作用域注册提示词段，**无 persona 覆盖风险**。持久化阶段再沉淀为 composition 插件行。
- **v1 = 动态插件 `dvlp-1/pkg-1`（运行中，run-1）**：`order: 10` 注册「默认开发工作流（dev-loop）」段（persona 之后、工具引导之前），host-only，apply 无错。**进程级，重启失效**。
- **L2 pre-step 提醒**：`PreStepDecision = {kind:'enter', messages} | {kind:'reject'}` 已确认；但 enter 分支是"带标识的冻结批次"，注入消息有破坏 agent loop 的风险——按"不过度设计、先闭环"原则推迟，待用户反馈后再加。
- **验证方式**：行为验证——下一开发任务是否自动走 研究→规划→执行→独立检查→对齐。
- **待办（后续迭代）**：① 插件行持久化进 `cordis.patch.yml`（重启存活）；② L2 pre-step 轻提醒（确认 UserMessage 形状后）；③ 触发词检测（v3.2.2 C1 八类）。
