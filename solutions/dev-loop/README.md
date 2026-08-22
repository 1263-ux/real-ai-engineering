# dev-loop

<p align="center">
  <img src="logo.jpg" alt="dev-loop" width="260" />
</p>

面向真实开发迭代的 AI 开发循环。

- **Problem**：多 Agent 协作反复出现「自我审批」「聊天上下文越滚越偏」「无限互审打补丁」——因为把角色写死，却没写清迭代规律。
- **Solution**：宪法 10 条 + Playbook + 状态机（DESIGN→PLAN→IMPLEMENT→VERIFY→TRIAL→DONE）+ Failure Routing（两次同类失败强制 RETHINK）+ 4 种工件 + 4 个人类门禁。
- **Use when**：需要规划 / 实现 / 验证 / 试用 / 迭代的软件开发任务；复杂任务、高风险变更、需要独立审查的场景。
- **Don't use when**：一次性小改动（直接做，别上流程）；不需要跨角色交接的单人任务。
- **Evidence**：v3.5 单一规范源；独立检查收敛到交付点（完成一轮 dev-loop / PR/推送/发布前 / 用户要求），fresh context 最多一次；硬阻塞（密钥泄露、真实数据损坏、权限越界、授权缺失）与 review 分离；公开方法论与本地资源配置分离，个人模型配置不入库。
- **Compatibility**：DSH（runtime adapter + 全局发现实测）；Codex（静态兼容，runtime 待验）；OpenCode（待验）。
- **Known limitations**：DSH 显式调用/加载待真实项目验证；Codex runtime discovery/invocation 待额度；OpenCode 未装未验。

## 布局

- `SKILL.md` — 宪法 + Playbook（可移植 policy）
- `templates/` — RESULT / EXPERT_PACKET / CURRENT_STATE
- `references/triad-engineering-closure.md` — 高风险 RC/发布/安全审计完整版（按需升级启用）
- `references/model-resources.md` — 公开抽象资源角色（具体模型/Provider/价格是用户资产，按需配置在本地，不入库）

## 安装（以 DSH 为例）

把本目录复制到 Agent 的 skills 目录，**目录名必须为 `dev-loop`**：

```powershell
# Windows (PowerShell)
New-Item -ItemType Directory -Force "$HOME\.agents\skills"
Copy-Item -Recurse "solutions\dev-loop" "$HOME\.agents\skills\dev-loop"

# macOS / Linux (bash)
mkdir -p ~/.agents/skills
cp -r solutions/dev-loop ~/.agents/skills/dev-loop
```

其他运行时（Codex / OpenCode）按各自的 skill 加载路径放置同名目录即可。

> DSH 平台增强（`adapters/dsh/`：原子替换、门禁脚本、平台 troubleshooting）位于仓库根目录，不在本安装包内；DSH 用户按需从仓库另行取用。
