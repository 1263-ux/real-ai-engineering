# real-ai-engineering

> 一句话：**一盒给 AI 编程助手的「岗位说明书 + 安全操作规程 + 辅助脚本」**。
> 都是我们在真实开发里踩坑后总结出来的，不是凭空设计的。

---

## 先搞懂 4 个词（30 秒）

| 词 | 人话 |
|---|---|
| **AI 编程助手** | 你能跟它对话、让它帮你读代码、改代码的工具（比如 Claude Code、Codex、Cursor、DSH） |
| **Skill（技能）** | 一份 Markdown 说明书：告诉 AI「遇到这类活，按什么步骤做、什么红线不能碰」 |
| **Adapter（适配器）** | 一段脚本，把说明书里的规则在某个具体工具上「强制执行」，不让 AI 靠自觉 |
| **Case（案例）** | 一次真实事故 + 它怎么被修好的记录，当回归样本用 |

一句话串起来：**Skill 告诉 AI「怎么做对」，Adapter 保证「它不能做错」，Case 记录「我们怎么摔过」**。

---

## 这是什么

一个开源仓库，专门收集「真实 AI 开发里逼出来的可复用东西」。

它不限定形态：有些是 50 行说明书（Skill），有些是脚本（Adapter），有些只是事故记录（Case）。
**只要它解决真实问题，就收。**

## 你需要什么

- 一台 **Windows 电脑**（当前两个方案都面向 Windows + PowerShell，PowerShell 是系统自带的）
- 一个 **AI 编程助手**（Claude Code / Codex / Cursor / DSH 等）
- 就这些。**Skill 本体只是一份 Markdown，不需要装任何额外的库、服务或平台。**

> 想看更细的兼容性，每个方案目录里都有「Compatibility」和「Known limitations」老实写着。

## 里面现在有什么

| 目录 | 是什么 | 解决什么问题（人话） |
|---|---|---|
| `solutions/dev-loop/` | 一份「怎么带 AI 做开发」的说明书 | AI 老是自己审自己、越聊越偏、来回打补丁——给它一套「谁定方向、谁写、谁证明、错了回到哪」的规矩 |
| `solutions/computer-management/` | 一份「怎么安全整理 Windows 硬盘」的说明书 + 档案模板 | 想清理 D 盘又怕弄坏软件/环境/数据——先盘点、分阶段、用你真正点开软件的方式验收，再动手 |
| `adapters/dsh/` | 让 dev-loop 的规则在 DSH 上「强制执行」的脚本 | 把「AI 只许读、不许乱写、失败不破坏旧文件」从「口头嘱咐」变成「代码管住」 |
| `cases/acceptance-drift/` | 一个真实事故 | AI 把 3 条验收标准自信地编成了 4 条，人也没发现——于是加了「验收必须带编号、不得增删改」的硬校验 |

> DSH = DeepSeek Harness，一个 AI 开发助手。

## 怎么用（三步）

1. **把 Skill 文件夹拷进你 AI 助手的技能目录**。比如 Codex 是 `%USERPROFILE%\.codex\skills\`，DSH 是 `~/.agents/skills/`（每个方案 README 里写了具体路径）。
2. **用大白话跟你的 AI 说**。比如「用 clean 帮我安全整理 D 盘，先只盘点、别删任何东西」。
3. **该拍板的拍板，别的别管**。Skill 里写好了哪几步必须等你确认、哪些它能自己干。

## 为什么可信

每条规则都不是「我觉得应该这样」，而是**从真实失败里长出来的**。

`cases/` 里留着事故原件：AI 在只有 3 条验收标准时，自信地验收了第 4 条。这套东西的意义就是——**允许 AI 犯错，但让错误在下一道便宜、确定的检查里被拦住**。

## 参与

- 发现问题 → 开 **Issue**（尤其是「在 XX 环境下会出问题」这类边界反馈，最值钱）。
- 想贡献 → 先过三道闸：**真实问题 → 成熟度 → 七问元信息**。
  七问：`Problem / Solution / Use when / Don't use when / Evidence / Compatibility / Known limitations`（其中 `Don't use when`、`Known limitations` 必填）。
- **允许小众**：一个只解决「Windows + PowerShell + Codex」痛点的东西照样欢迎，只要老实写清「不适合谁」。

## License

MIT
