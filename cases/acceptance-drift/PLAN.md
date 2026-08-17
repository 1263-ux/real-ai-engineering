# PLAN

> 由 plan 脚本生成（脚本 v3.1 / 协议 v2.2，规划器：claude）。执行前必须把 status 改为 approved；DSH 只执行 approved 的计划。

## Metadata

- plan_id: plan-20260816-204626071
- design_version: 2026-08-16-01
- design_status: approved
- generated_by: claude (model: opus[1m]; claude: 2.1.220 (Claude Code))
- generated_at: 2026-08-16T20:46:26+08:00
- status: approved

### Task 1：只读核实仓库与全局文档结构
Status: TODO

目标：核对 README 中将引用的路径真实存在，为「目录与文档导航」提供准确指路依据，避免 README 指向不存在的文件。范围：仓库根目录下 `agent-workflow-v2/` 源码；全局 `~/.dsh/workflow/` 下的 WORKFLOW.md（用户版）、agent-handoff.md、templates/、codex-plan.ps1。

涉及文件：README.md（引用路径的来源，本任务只读核对，不写入）、`agent-workflow-v2/`、`~/.dsh/workflow/` 相关文档（只读）。

依赖：无

风险：路径与实际不符，导致 README 指路失效；在只读核对过程中误改现有文件（须严格只读）。

执行者：DSH agent

验收标准：产出一份可直接用于 README 的路径清单，与 DESIGN.md Context 所述结构一致；未对任何现有文件产生改动。

### Task 2：撰写 README.md 全文
Status: TODO

目标：按 DESIGN.md 的 Goal / Constraints / Decision，新增单文件、指路型、中文 Markdown 的 `README.md`，让首次到访者 3 分钟内理解仓库是什么、三个入口怎么用、文件放哪里。内容必须覆盖四块：一句话定位；三入口用法（日常 / 先规划 / 高价值把关）；目录与文档导航（全局 `~/.dsh/workflow/` vs 项目 `.agent/`）；e2e 快速开始（含 `-Planner claude` 无额度路径）。

涉及文件：`README.md`（新增，唯一写入的文件）。

依赖：Task 1

风险：把 WORKFLOW.md / agent-handoff.md 全文抄进 README（违反 Non-goals）；三入口描述与真实用法不符；e2e 快速开始缺 `-Planner claude` 无额度路径。

执行者：DSH agent

验收标准：仓库根目录出现 `README.md`；中文 Markdown；内容含一句话定位、三入口用法、目录与文档导航（全局 vs 项目 `.agent/`）、e2e 快速开始（含 `-Planner claude` 无额度路径）；不引入构建工具或依赖；未复制 WORKFLOW.md / agent-handoff.md 全文。

### Task 3：DSH agent 自检对照验收清单
Status: TODO

目标：对照 DESIGN.md 的 Acceptance Criteria 与 Constraints 逐条核验 Task 2 的产物，发现缺漏即回改。

涉及文件：`README.md`（只读核验 + 必要修订）、仓库现有文件（只读比对）。

依赖：Task 2

风险：漏检某一验收项（尤其「除 README.md 外零改动」）；仅凭代码/文本阅读判断，未实际确认文件改动范围。

执行者：DSH agent

验收标准：四条 Acceptance Criteria 全部满足；确认除新增 `README.md` 外，仓库现有文件零改动（可用目录清单或 diff 佐证）；自检发现的问题已在 README.md 中修正。

### Task 4：人工终验
Status: TODO

目标：由人工对交付物做最终确认，签字通过 DESIGN.md 验收标准。

涉及文件：`README.md`、仓库现有文件（终验比对）。

依赖：Task 3

风险：人工终验与自检口径不一致，或遗漏「零改动」的最终确认。

执行者：人工

验收标准：人工确认 `README.md` 内容完整可用、三入口描述准确、e2e 快速开始可实际走通；确认除新增 `README.md` 外仓库现有文件零改动；DESIGN.md 四条 Acceptance Criteria 全部签字通过。
