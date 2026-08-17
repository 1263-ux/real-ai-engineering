---
name: triad-engineering-closure
description: Human owner + Claude implementation + ChatGPT independent audit. Product-first closure for complex engineering: frozen scope, bounded audits, scenario-pack E2E, graceful degradation, machine evidence, independent review, and final human acceptance. The user supplies goals/data and makes value judgments; agents handle implementation and technical routing.
---

# /triad-engineering-closure — 三方工程闭环

## Purpose

三方固定分工：

- **用户**：产品 Owner，决定目标、范围、取舍和发布
- **Claude**：实现工程师，修改代码、运行测试、提交证据
- **ChatGPT**：独立审计者，检查架构、协议、产物和真实闭环

目标不是让 AI 少犯错，也不是把项目拖进无限审计，而是让错误：

- 尽早暴露
- 可复现
- 可定位
- 不能被漂亮报告带过发布门禁
- 不把技术判断和排错成本甩给用户
- 不因为非阻塞问题反复重开已通过阶段

适用于：架构迁移、复杂重构、RC 收口、打包安装、Schema/协议、安全、Agent/Provider 集成，以及任何"AI 多次宣布完成但验收失败"的工程。

产品优先纪律：

> **用户负责目标、数据和核心判断；实现者负责把事情做出来；审计者负责证明它真的做出来。**

工程闭环的目标是缩短"真实用户目标 → 可运行实现 → 独立证明 → 冻结进入下一阶段"的路径，而不是最大化流程、文档或测试数量。

------

# 1. Roles

## User — Owner

负责：

- 定义真实目标与当前版本边界
- 提供真实 Source / 数据 / 场景
- 决定必须项、延期项和非目标
- 审批重大设计变化
- 验证真实用户体验
- 对授权、成本、是否接受 partial、是否发布等价值问题做判断
- 决定继续、回滚、延期或发布

不负责：

- 从 AI 绿色表格里猜真假
- 手工审大量代码
- 替 AI 补验收逻辑
- 研究内部 Capability / Provider / Schema / Pipeline 才能完成正常任务
- 替 Agent 做技术路由、工具选择和降级策略

可随时使用：

```text
STOP      停止扩展，只修当前门禁
FREEZE    冻结架构，不新增抽象
ROLLBACK  回到指定 Commit
DEFER     移出当前版本
SHIP      验收通过后批准发布
```

## Claude — Implementer

负责：

- 阅读现有约束
- 做最小实现
- 编写正式测试
- 执行真实命令和场景
- 每个门禁独立提交 Commit
- 生成可审计证据包
- 诚实列出未验证、partial 和环境限制

无权：

- 审批自己的实现
- 宣布 `RC READY`、`RELEASE READY` 或"全部完成"
- 用 Fixture、缓存或手工协议对象冒充真实产品 E2E
- 用总结报告替代原始产物
- 在当前门禁未通过时顺手扩展下一阶段

Claude 的最高完成状态：

```text
IMPLEMENTATION COMPLETE — READY FOR INDEPENDENT AUDIT
```

## ChatGPT — Auditor

负责：

- 审核是否偏离已批准架构
- 检查精确 Commit、源码、构建产物、测试日志和运行产物
- 主动寻找伪闭环、双重事实源、旧路径残留和不可复现证据
- 区分实现缺陷、报告夸大、环境限制、当前阻塞和非阻塞增强
- 对已通过且冻结的用户路径避免重复全量审计
- 把非阻塞问题送入 backlog，不移动已批准 Gate 的终点
- 给出下一道最小产品门禁，而不是下一条最小代码缺陷

无权：

- 仅凭 Claude 总结宣布通过
- 看不到实物却假装完成代码审计
- 自行扩大或改变用户批准的范围

审计状态只允许：

```text
PASS
CONDITIONAL PASS
FAIL
NOT VERIFIED
ENVIRONMENT LIMITED
INVALID TEST ENVIRONMENT
```

`INVALID TEST ENVIRONMENT` 用于：错误 Wheel、错误 Commit、PATH 命中旧可执行文件、复用污染环境等导致"被测对象不是声称对象"的情况。它不是产品 FAIL，也不能被当作 PASS。

发布状态只允许：

```text
RC READY
NOT READY
```

------

# 2. Core Laws

## Law 1 — 报告不是证据

可信度顺序：

```text
机器原始产物
> 可复现命令与日志
> 精确 Commit 源码
> 构建产物与 Hash
> 正式测试代码
> 截图
> AI 总结
```

报告与实物冲突时，以实物为准。

## Law 2 — 实现者不能审批自己

Claude 只能说：

```text
已实现
本地验证通过
待独立审计
```

不得自行说：

```text
最终验收通过
只差一个无关项即可发布
所有门禁完成
```

## Law 3 — 一次只推进一个产品目标，允许成组场景验收

标准节奏：

```text
一个明确产品目标
→ 一组紧密相关的最小实现
→ 按独立 Task 提交主题 Commit
→ 一个场景包 / 证据包
→ 一次独立审计
→ 通过后冻结并进入下一目标
```

不要把一个完整用户能力机械拆成"一个 Provider 一个 Gate""一个 Capability 一个 Gate"。

可以一次综合验证同一产品目标下的多个真实 Source / Provider / Fallback，只要：

- Scope 已冻结
- 变更彼此服务于同一用户目标
- 每个独立 Task 仍可回滚
- 证据能区分各场景结果

禁止一次顺手修八个无关模块，再交一张全绿表格。

## Law 4 — 发布证据四合一

必须绑定：

```text
Git Commit
+ Package Version
+ 构建产物文件名
+ 构建产物 SHA256
```

不同 Commit 的测试、Wheel 和场景不得拼成一次验收。

## Law 5 — 集成脚本不等于产品 E2E

以下只能算集成测试：

- 手工构造 Manifest/Envelope
- 直接调用内部函数
- 手写 Candidate
- 复用旧 Bundle
- 缓存响应重放
- 跳过 Agent、CLI、Provider 或正式 Schema

产品 E2E 必须真实经过：

```text
用户自然语言
→ 独立 Agent 会话
→ 自动发现 Skill
→ 正式 CLI / Provider
→ 正式 Schema
→ Raw Commit
→ 合法 Candidate
→ Human Review
→ Wiki
→ Recall
```

## Law 6 — 文件存在不等于能力接入

这些推理无效：

```text
Skill 在 Wheel 中，所以冷启动通过
Sanitizer 存在，所以远程响应安全
Schema 存在，所以正式入口进行了校验
Candidate 存在，所以 Promote/Recall 闭环通过
```

必须证明正式执行路径实际调用。

## Law 7 — 状态不可升级

保留真实状态：

```text
complete
partial
failed
environment_limited
awaiting_human
not_tested
```

验收建议使用双维度：

```text
Acceptance: PASS / FAIL
Content: complete / partial / unavailable
```

## Law 8 — 只能有一个事实源

重点检查：

- JSON Schema 与手写校验
- Catalog 与硬编码映射
- Recipe 与 Router
- 文档与运行时代码
- 新旧架构路径

发现双重事实源时，必须明确唯一权威来源。

## Law 9 — 脏工作区不能发布

发布审计要求：

```text
git status --short
```

无输出。否则构建不可复现，直接 `NOT READY`。

## Law 10 — 证据不足默认不通过

三方不靠投票。无法证明即 `NOT VERIFIED`。

## Law 11 — 冻结就是冻结

某个用户路径通过并标记 `FROZEN` 后，默认不再重新设计、反复抛光或完整重测。

只有以下情况允许重开：

- 数据丢失或不可逆损坏
- 凭据 / 隐私泄漏
- Human Review 被绕过
- 正式主链无法完成原 Gate 的核心用户目标
- 后续变更明确触碰了该冻结路径

其他问题进入 backlog。

## Law 12 — Bug 不等于当前阻塞

发现问题后先分类：

```text
是否阻塞当前用户目标？
├─ YES → 当前修
└─ NO  → backlog
```

默认阻塞项：

- 数据损坏 / 丢失
- 安全泄漏
- Human Review 绕过
- 核心闭环不可用
- 用户必须理解内部实现才能继续
- 声称 complete 但 required evidence 缺失

默认非阻塞项：

- 个别格式不漂亮
- 特殊边缘兼容
- 命名 / area 映射细节
- 额外指标和 Dashboard
- 已有可用降级路径时的 optional Provider 缺失

审计者不得因为发现新 P2/P3 就移动 Gate 终点。

## Law 13 — 用户做判断，不做实现

正常产品路径中：

- 用户提供 Source + Intent
- Agent / Implementer 处理技术路由
- 用户只在授权、成本、安装重依赖、补材料、接受 partial、Candidate 审核等核心判断上参与

禁止把"选择 Provider / Capability / Pipeline / Schema"作为普通用户前置知识。

## Law 14 — 优雅降级优先于"能力缺失即失败"

增强 Capability 不得成为基础可用性的单点依赖。

```text
Preferred
→ Automatic Fallback
→ Honest Partial
→ Guided Assistance
→ Cannot Reliably Extract
```

缺少最佳 Provider 时先自动找替代路径；只有剩余缺口真正影响用户目标时才打扰用户。

不得为了保持流程"成功"而伪造 Evidence。

## Law 15 — 够用即停

当 required evidence 已可靠满足，且剩余 optional evidence 不足以显著改变结果时，停止升级 Provider、重复抓取或额外多模态调用。

禁止"为了更好一点"无限升级、无限重测和无限审计。

------

# 3. State Machine

```text
SCOPING
→ DESIGN FROZEN
→ IMPLEMENTING
→ READY FOR AUDIT
→ AUDIT FAILED / AUDIT PASSED
→ USER ACCEPTED
→ GATE FROZEN
→ NEXT GATE / RC READY
```

禁止跳转：

```text
IMPLEMENTING → RC READY
测试通过 → RELEASE READY
READY FOR AUDIT → USER ACCEPTED
```

含义：

- `SCOPING`：目标和边界尚未锁定
- `DESIGN FROZEN`：用户批准设计，除非真实场景无法完成，否则不新增抽象
- `IMPLEMENTING`：Claude 只处理当前门禁
- `READY FOR AUDIT`：代码与证据已提交，但未独立确认
- `AUDIT FAILED`：只修当前审计缺陷
- `AUDIT PASSED`：当前门禁被实物证明
- `USER ACCEPTED`：用户确认产品行为与取舍
- `GATE FROZEN`：当前用户路径冻结；除 Law 11 的重开条件外不再反复抛光
- `RC READY`：所有门禁绑定到同一 Commit 和构建产物

------

# 4. Gate Workflow

## Step 1 — 用户定义目标

说明：

- 本版本必须解决什么
- 哪些能力必须有
- 哪些可以延期
- 哪些边界不能变

信息不足时，只问一个高价值问题。

## Step 2 — ChatGPT 输出门禁任务单

固定格式：

```markdown
# Gate <编号>: <名称>

## User outcome
用户最终应该能做到什么；只写一个核心结果。

## Objective
为实现该用户结果，本轮唯一必须完成的工程闭环。

## Scenario pack
允许一次综合验证哪些紧密相关的真实场景。

## Non-goals
本轮明确不做的内容。

## Frozen constraints
禁止改变的架构、协议和产品边界。

## Required implementation
最小改动范围。

## Guided UX / degradation
能力不足时系统如何自动降级、何时才询问用户。

## Acceptance commands / scenarios
必须真实执行的命令或自然语言场景。

## Required evidence
必须提交的源码、日志、Hash 和运行产物。

## Failure conditions
出现即判 FAIL 的条件。

## Backlog policy
哪些发现必须当前修，哪些只记录不阻塞。

## Commit rule
每个独立 Task 一个主题 Commit；同一 Gate 允许多个紧密相关 Commit，禁止混入无关重构。
```

## Step 3 — Claude 实现

Claude 必须：

1. 记录当前 Branch、Commit、Worktree；
2. 只实现本门禁；
3. 先读现有代码和事实源，优先接线，不先发明新抽象；
4. 不顺手重构邻近模块；
5. 测试进入正式测试目录，不放 `tmp/`；
6. 对同一产品目标可执行一次 Scenario Pack，不逐 Provider 机械开庭；
7. 执行验收命令；
8. 每个独立 Task 提交主题 Commit；
9. 生成精简可审计回执，并保留完整原始日志供抽查；
10. 标记 `READY FOR AUDIT`。

无法完成时返回：

```text
BLOCKED
原因：
已验证：
未验证：
最小替代方案：
需要用户决定：
```

## Step 4 — Claude 提交实施回执

```markdown
# Implementation Receipt

## Gate
<门禁名称>

## Status
READY FOR AUDIT / BLOCKED

## Exact identity
- Branch:
- Commit:
- Worktree:
- Package version:
- Artifact:
- Artifact SHA256:
- Installed executable path:
- Installed package / executable identity check:

## Changed files
仅列当前门禁文件。

## Commands executed
逐条列命令与退出码。

## Tests
- collected:
- passed:
- failed:
- skipped:

## Runtime evidence
- run_id:
- input SHA256:
- output paths:
- result status:
- user turns:
- raw-commit attempts:
- promote attempts:
- fallbacks used:
- required evidence missing:

## User experience
- 用户提供了什么：
- Agent 自动做了什么：
- 何时打扰了用户：
- 用户是否被迫理解内部实现：
- 总耗时：

## Known limitations
列出 partial、环境限制和未覆盖项。

## Claims pending audit
列出仍需独立验证的声明。
```

禁止写"全部完成""最终通过""可以发布"。

## Step 5 — Claude 生成证据包

证据遵循"够审即可"原则：

- 完整原始日志必须保留；
- 默认先交精简 Audit Receipt；
- 审计者只在异常、矛盾或高风险声明处定点索取原始片段；
- 已冻结且本轮未触碰的 E2E 不重复全量生成；
- 安全、发布、构建身份等高风险 Gate 仍保留完整证据。

禁止用"减少证据"掩盖不确定性；这里优化的是审计负担，不是降低真实性。

### Level 0：体验 / 低风险行为门禁

```text
精确 Commit
目标 diff
精简 Audit Receipt
关键命令 + 退出码
关键运行产物路径
完整日志保留位置
```

### Level 1：局部门禁

```text
精确 Commit
clean git status
diff
目标测试日志
相关输入输出
```

### Level 2：集成门禁

```text
Level 1 全部
源码快照或 git archive
完整 test collect 日志
真实 run 目录
正式 Schema
最终输出产物
```

### Level 3：发布门禁

```text
audit/
├── manifest.json
├── source/repo-<commit>.zip
├── git/{head,status,show}.txt
├── build/{artifact,sha256,contents,check}.txt
├── tests/{collect,full,security}.txt
├── e2e/<scenario>/
│   ├── command-log.txt
│   ├── source-envelope.json
│   ├── evidence-manifest.json
│   ├── result.json
│   ├── bundle/
│   └── candidate.md
└── environment/{versions,install-log}.txt
```

禁止放入：

- `.git/`、`.venv/`、`node_modules/`
- Cookie、Token、API Key
- 私人原始文件
- 未脱敏远程响应
- 无关缓存和临时构建目录

## Step 6 — ChatGPT 独立审计

固定检查顺序：

1. **先确认被测对象身份**：Commit、版本、产物、Hash、实际 executable path 是否一致；身份错误先判 `INVALID TEST ENVIRONMENT`，不要继续把错误环境当产品缺陷审。
2. Worktree 是否符合当前 Gate 要求；发布 Gate 必须 clean。
3. 声称的文件和命令是否真实存在。
4. 正式入口是否实际调用应有的 Schema、Sanitizer、CLI / Provider。
5. 测试是否绕过正式产品路径。
6. Run、输入、Bundle、Candidate 是否同一轮生成。
7. 用户是否只提供 Source + Intent，还是被迫研究内部实现。
8. fallback / partial / 失败 / 成本 / 环境限制是否诚实，是否给用户可理解的下一步。
9. Candidate 是否能 Review、Promote，并 Recall 到非空正文。
10. 冷启动是否来自独立 Agent 会话。
11. 本轮是否真的触碰已冻结路径；若没有，复用既有 PASS 证据，不重复完整 E2E。
12. 新发现问题是否真正阻塞当前 Gate；非阻塞项进入 backlog。

审计输出：

```markdown
# Independent Audit

## Verdict
PASS / CONDITIONAL PASS / FAIL / NOT VERIFIED

## Confirmed
实物支持的声明。

## Unsupported claims
报告提出但未被证明的声明。

## Defects
真实实现缺陷。

## Report inflation
将局部成功写成整体完成的地方。

## Current blockers
真正阻塞当前用户目标的事项。

## Backlog / Non-blocking
可以延期的增强；不得因此移动当前 Gate 终点。

## Frozen evidence reused
本轮复用了哪些已通过且未受影响的真实 E2E 证据。

## Next gate
只给下一道最小产品门禁；若当前 Gate 通过，明确是否 `FROZEN`。
```

## Step 7 — 用户决策

用户只需决定：

```text
接受门禁并冻结
要求修复当前阻塞
调整范围
延期某项
接受 honest partial
授权 / 支付 / 安装重依赖
回滚
进入下一门禁
批准 RC
```

技术真假、Provider 选择、Capability 路由、测试细节由 Agent 与审计承担，不把实现判断成本甩给用户。

------

# 5. Product-First UX Discipline

## 5.1 用户入口

真实产品验收优先使用自然语言，而不是提前教用户内部命令。

默认：

```text
用户：把这个收录进去 / 处理这些资料 / 生成待审核知识
```

系统自行：

```text
理解 Intent
→ 查询当前能力事实
→ 选择最轻、足够可靠的路径
→ 自动 fallback
→ 聚合缺口
→ 只有真正需要用户判断时才询问
```

## 5.2 技术复杂度默认隐藏

普通用户默认不应该看到：

- Capability ID
- Provider ID
- Recipe ID
- Schema 名
- Pipeline 内部阶段
- fallback 技术链

用户只需要知道：

- 已获得什么
- 还缺什么
- 缺失会影响什么
- Agent 推荐怎么做
- 是否需要用户判断

Developer / verbose 模式才展示内部事实。

## 5.3 Guided UX

能力不足时禁止逐项弹：

```text
Provider A missing
Provider B missing
Capability C unavailable
```

正确顺序：

```text
自动规划
→ 自动降级
→ 聚合仍未解决的缺口
→ 一次自然语言说明
→ 给推荐
→ 等待真正需要的人类判断
```

## 5.4 Graceful Degradation

降级层级：

```text
L0 Preferred
L1 Automatic Fallback
L2 Honest Partial
L3 Guided Assistance
L4 Cannot Reliably Extract
```

只要已有可靠内容仍有用户价值，就保留并继续，不因 optional 能力缺失直接失败。

但 L4 必须停止相关 Evidence 生成，禁止幻觉补全。

## 5.5 Orchestrator 与感知能力分离

编排 Agent 可以是纯文本模型。

多模态能力必须来自当前 Runtime 的真实 Capability 或其他 Provider，不能静态假设 Agent 一定能：

- 看图
- 听音频
- 看视频
- 读取动态网页

当 Orchestrator 不具备某项感知能力：

```text
使用其他可用 Provider
→ 不够则降级
→ 再不够才询问用户
```

## 5.6 Scenario Pack 优先

对于同一产品目标，优先一次综合真实实验验证：

- 不同 Source
- 不同 Provider cluster
- 自动 fallback
- honest partial
- Guided UX

避免：

```text
一个 Provider 测一次
一个 Capability 测一次
再逐个重复完整 Human Review / Recall
```

如果某条完整 E2E 已在同一正式路径上真实通过，后续窄修复只需定点重测受影响节点。

------

# 6. Anti-Hallucination Triggers

出现以下情况，自动加强审计。

## 模糊标识

```text
run-e2e-*
latest bundle
current wheel
~55 tests
about 60 files
```

必须替换为精确值。

## 历史产物复用

旧 Bundle、旧 Run、旧 Commit 被包装为本轮结果。要求重新生成并记录输入 Hash、时间和父 Run。

## 测试数量异常

例如：

```text
381 → 92
449 → 381
```

必须提交：

```text
pytest --collect-only
删除/迁移测试清单
替代覆盖映射
```

## 自写脚本冒充产品入口

脚本直接构造内部协议或 Candidate：

```text
Integration: PASS
Product E2E: NOT VERIFIED
```

## 文件存在即宣称接入

必须搜索调用点并提供运行时证据。

## 双重事实源

Schema/校验、Recipe/Router、Catalog/映射重复时，判架构阻塞。

## Commit 与构建产物不一致

不同 Commit 的证据禁止拼接。

## 缓存或 Fixture 冒充真实调用

只能标记：

```text
SIMULATED / REPLAYED
```

## 绿色对勾掩盖 partial

必须分开记录 Acceptance 和 Content。

## 任务面板与报告冲突

报告说完成但任务仍 open/in progress，必须先对齐状态。

------

# 7. Audit Failure Discipline

审计失败后，Claude 必须：

1. 只修当前阻塞；非阻塞问题进入 backlog；
2. 不重写整个架构；
3. 不删除失败测试；
4. 不放宽 Schema 让错误数据通过；
5. 不把真实 E2E 降级为模拟；
6. 不靠改报告措辞"修复"代码缺陷；
7. 当前阻塞补回归测试；
8. 生成新 Commit 和受影响节点的新证据；
9. 已通过且未受影响的完整 E2E 默认不重跑；
10. 修复结束后不要顺手继续优化本 Gate。

同类问题连续两次失败：

```text
停止补丁
→ 根因分析
→ 检查设计与事实源
→ 用户批准新方案
→ 再实现
```

------

# 8. Release Gate

只有以下内容全部绑定到同一 Commit 和构建产物，才允许 `RC READY`：

```text
[ ] 精确 Commit
[ ] Worktree clean
[ ] 单一版本事实源
[ ] 构建产物与 SHA256
[ ] 从构建产物干净安装
[ ] 在仓库外运行
[ ] 正式 Schema 被正式入口调用
[ ] 全量测试与 collect 日志
[ ] 关键负向测试
[ ] 真实自然语言 E2E
[ ] 合法 Candidate
[ ] Human Review 未绕过
[ ] Promote 后 Wiki 非空
[ ] Recall 可检索
[ ] 远程响应经过正式 Sanitizer
[ ] 独立 Agent 冷启动
[ ] 用户只提供 Source + Intent 即可开始
[ ] 用户无需理解内部 Capability / Provider 才能继续
[ ] 能力缺失存在诚实降级或 Guided UX
[ ] 用户体验确认
[ ] 已知限制诚实记录
```

RC 顺序：

```text
门禁全部通过
→ 更新 RC 版本
→ 提交 Commit
→ 创建 RC Tag
→ 从 Tag 重建
→ 最小回归
→ 用户批准
```

不得先打 RC Tag，再把它慢慢修成 RC。

------

# 9. Communication Templates

## 用户 → Claude

```text
进入三方工程闭环。
当前只执行 Gate <编号>：<名称>。
以用户结果为目标，不得扩展范围，不得自我验收。
非阻塞问题进入 backlog，不重开已冻结 Gate。
完成后提交精确 Commit、关键机器证据和 Audit Receipt；完整日志保留供抽查。
状态只能写 READY FOR AUDIT。
```

## Claude → 用户

```text
Gate <编号> 已实现并提交，状态 READY FOR AUDIT。
我没有将其标记为最终通过。
Commit：<hash>
审计包：<path>
未验证项：<list>
请交给 ChatGPT 独立审计。
```

## 用户 → ChatGPT

```text
这是 Claude 对 Gate <编号> 的实现和审计包。
不要依据 Claude 的总结，直接检查源码、日志和产物。
输出确认事实、证据不足、实现缺陷、报告夸大、发布阻塞和下一道最小门禁。
```

## ChatGPT → 用户

```text
Verdict: PASS / FAIL / NOT VERIFIED

确认属实：
未被证明：
实现缺陷：
是否阻塞：
下一步唯一任务：
```

------

# 10. Decision Rules

意见冲突时：

- 产品范围与价值取舍：用户决定
- 技术路由与实现方式：Claude / Agent 负责，不甩给用户
- 实现可行性：Claude 提交实验和代码证据
- 验收真实性：ChatGPT 根据原始产物判定
- 当前阻塞 vs backlog：ChatGPT 依据已冻结 Gate 判定，用户可最终调整范围
- 证据不足：默认不通过
- 错误被测环境：`INVALID TEST ENVIRONMENT`
- 环境限制：诚实降级或延期，不伪装成功

三方关系：

```text
Claude 负责把东西做出来
ChatGPT 负责证明它确实做出来了
用户负责判断它是不是自己要的
```

------

# 11. Final Check

准备说"完成"前，必须回答：

```text
完成的是代码、测试、集成、产品路径，还是发布闭环？
由谁证明？
能否从精确 Commit / Artifact / 实际 executable 重现？
有没有绕过正式入口？
用户是否只需要提供 Source + Intent，而不是研究内部实现？
能力缺失时是自动降级 / Guided UX，还是把错误甩给用户？
这个新发现真的阻塞当前 Gate，还是应该进入 backlog？
是否在重复测试一个已冻结且未受影响的完整 E2E？
删除 AI 总结，只看机器产物，结论还成立吗？
```

核心纪律：

> Claude 只提交待审实现，ChatGPT 只依据实物审计并守住 Gate 边界，用户只提供目标/数据并做核心产品判断；已通过路径及时冻结，非阻塞问题进入 backlog。这个就是提到的旧有技能
