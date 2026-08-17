# computer-management

`clean`（技能）+ `template`（档案模板）搭配使用：安全整理 Windows 开发数据盘，并把机器建成一套可回溯、可验证、可恢复的管理档案。

- **Problem**：D 盘堆满开发工具 / 依赖缓存 / Docker / WSL / VMware / 项目 / 个人数据，直接清理会弄坏应用、环境或数据；缺一套「先盘点、分阶段、真入口验证、管理员验收」的纪律。
- **Solution**：`clean` = 只读盘点 → 风险分级 → Stage A/B/C/D 分阶段 → 真实入口验证 → 管理员/用户验收 → 写回档案；`template` = 00–07 目录的持久档案（现状 / 软件路径 / 开发环境 / 虚拟化 / 使用指南 / 维护日志 / 备份恢复）+ AGENTS.md 操作边界。
- **Use when**：整理/重构 Windows 数据盘、迁移依赖缓存、修复路径/快捷方式、周期性存储维护。
- **Don't use when**：只是想「把根目录变好看」；目标盘不含开发环境/虚拟化/数据库。
- **Evidence**：盘点脚本已在真实 D 盘执行并生成 JSON；验收脚本已验关键目录、开发命令、快捷方式、VHDX。
- **Compatibility**：Codex（已验，`%USERPROFILE%\.codex\skills\clean`）；DSH / OpenCode 未验。
- **Known limitations**：仅 Windows + PowerShell；DSH / OpenCode 兼容性未验；`agents/openai.yaml` 的显示名编码曾在源文件损坏，入库前已修。

## 搭配方式

- `template/` = 持久知识 + 规则（这台机器记什么、红线在哪）。
- `clean/` = 操作技能（怎么安全地盘点、整理、验证）。
- 两者**分开分发**：clean 不打包进 template；AGENTS.md 要求先读 `clean/SKILL.md`，clean 的 Phase 6 产物落进 template 的 00–07。
