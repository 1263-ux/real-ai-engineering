# clean 技能说明

## 目的

`clean` 用于安全整理 Windows 数据盘，尤其适合包含开发工具、项目、依赖缓存、Docker、WSL、VMware、数据库和个人数据的 D 盘。

它的核心不是“把根目录变漂亮”，而是在不破坏应用、开发环境和数据的前提下完成盘点、规划、分阶段整理、验证、管理员验收和长期维护。

## 包含内容

- `SKILL.md`：主工作流和强制安全门禁。
- `references/risk-model.md`：100/90/70/50/30/10 权重与风险分级。
- `references/windows-path-repair.md`：快捷方式、文件关联、注册表、更新器和卸载路径修复方法。
- `references/validation-and-acceptance.md`：Codex 自验与管理员/用户验收矩阵。
- `scripts/Get-DriveInventory.ps1`：只读盘点 Windows 数据盘并输出 JSON。
- `scripts/Test-PostClean.ps1`：验证关键路径、命令、快捷方式、PATH 和虚拟磁盘。
- `assets/plan-template.md`：整理计划和移动清单模板。
- `assets/maintenance-record-template.md`：维护记录和验收模板。

## 安装给其他 Codex

把整个 `clean` 文件夹复制到目标电脑的 Codex 技能目录：

```text
%USERPROFILE%\.codex\skills\clean
```

重新打开 Codex 后即可使用。

## 使用示例

```text
使用 $clean 先只读盘点我的 D 盘，制定目标结构和分阶段计划，不要移动或删除任何文件。
```

```text
使用 $clean 检查上次整理后失效的快捷方式、环境变量和 Markdown 打开方式，先备份再修复并验证。
```

```text
使用 $clean 将 npm、pnpm、uv、pip、Maven 和 Gradle 缓存迁移到 D 盘，保留旧缓存直到新路径验证成功。
```

## 默认安全策略

- 不为视觉整齐直接搬动已安装软件。
- 不自动删除重复文件、旧缓存、Docker Volume 或虚拟磁盘。
- 不使用 Docker 恢复出厂设置或带 Volume 的清理命令。
- 不把“进程启动”当作完整验证。
- 每阶段完成后都用真实用户入口验证。
- 删除、卸载、重装、管理员改动和重要数据操作必须单独确认。

## 验证情况

- 标准技能结构验证通过。
- 盘点脚本已在真实 D 盘执行并生成 JSON 报告。
- 验收脚本已验证关键目录、开发命令、桌面快捷方式和 VHDX。
- 技能不包含用户密钥或个人数据值。

