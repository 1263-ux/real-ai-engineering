<#
.SYNOPSIS
  用 Codex 或 Claude（→DeepSeek）非交互生成顶层执行计划，写入 <项目>/.agent/PLAN.md（只读 + 原子替换 + 强校验）。

.DESCRIPTION
  脚本 v3.1（协议 v2.2 机制 + 项目化布局 + -Planner 双后端）：
    0. 布局：状态文件放在每个项目的 .agent/ 下（DESIGN/PLAN/STATUS + 运行日志），
       全局只装本脚本和模板（~/.dsh/workflow/）。DSH 每次按项目显式传 -Workspace。
    1. 规划器只读由 runtime 强制（非靠 prompt）：Codex = --sandbox read-only +
       -c approval_policy=never；Claude = --bare -p --tools=（--tools= 等价 --tools ""，
       用 = 空值绕开 PS5.1 吞空串；--bare 跳过 hooks/skills/plugins/MCP/CLAUDE.md）。
    2. 输出：codex exec --output-last-message/-o 让 Codex 直写文件（UTF-8），
       绕开 PowerShell 5.1 的 `1>` 重定向默认 UTF-16LE 编码坑。
       调用前清理 outFile/errFile，杜绝 stale 输出；exit 0 后 outFile 必须存在。
    3. 原子替换：[IO.File]::Replace(tmp, plan, bak) 一步完成替换+备份（replacement
       semantics，不预删 bak）；失败即退出码 4，无 fallback——旧 PLAN 原样保留。
    4. 计划头由脚本注入：plan_id（毫秒级唯一）、design_version（引用来源 DESIGN）、
       design_status、generated_by、generated_at、status: draft。
    5. -FromDesign fail-closed：DESIGN.md 必须存在、design_version 非空、
       status 必须 approved，否则退出码 5（= DESIGN contract invalid）。
    6. 输出合同：正文必须以 `### Task N：<标题>` 组织；每个 Task 块必须含
       Status:/目标/涉及文件/验收标准 四个字段（逐 Task 校验，非全文出现一次即过）。
       -FromDesign 时还校验 DESIGN 的 AC id 集合与 PLAN 引用一致（不得增删改）。
    7. 退出码：0=成功；1=Codex 失败；2=输出校验失败（含 exit 0 但无输出文件）；
       3=规划器（codex/claude）不在 PATH；4=写入/替换失败；5=DESIGN contract invalid；6=Workspace 无效。

.PARAMETER Request
  需求描述（必填，第一个位置参数）。

.PARAMETER FromDesign
  以 <项目>/.agent/DESIGN.md 为准出计划；fail-closed 校验（推荐用法）。

.PARAMETER Workspace
  项目根目录（绝对路径）；缺省为当前目录。DSH 调用时总是显式传入。

.EXAMPLE
  .\codex-plan.ps1 -FromDesign "按 DESIGN.md 出计划" -Workspace "D:\Projects\oks"
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Request,
    [switch]$FromDesign,
    [string]$Workspace,
    [ValidateSet('codex', 'claude')][string]$Planner = 'codex'
)

# PS 5.1 兼容：不靠 $ErrorActionPreference 兜底，成败一律显式检查
$ErrorActionPreference = 'Continue'

# --- 0. 工作区解析（-Workspace 优先，否则当前目录） -----------------------------
if ($Workspace) {
    # 注意：$ErrorActionPreference=Continue 下 Resolve-Path 报的是非终止错误，try/catch 接不住，必须显式判空
    $resolved = Resolve-Path $Workspace -ErrorAction SilentlyContinue
    if ($resolved) {
        $ws = $resolved.Path
    } else {
        Write-Host "ERROR: Workspace 路径无效：$Workspace" -ForegroundColor Red
        exit 6
    }
} else {
    $ws = (Get-Location).Path
}
if (-not (Test-Path $ws -PathType Container)) {
    Write-Host "ERROR: Workspace 不是有效目录：$ws" -ForegroundColor Red
    exit 6
}

# --- 0.5 项目状态目录：<项目>/.agent/ -------------------------------------------
$agentDir = Join-Path $ws '.agent'
New-Item -ItemType Directory -Force -Path $agentDir | Out-Null
$plan       = Join-Path $agentDir 'PLAN.md'
$tmp        = Join-Path $agentDir 'PLAN.md.tmp'
$bak        = Join-Path $agentDir 'PLAN.md.bak'
$outFile    = Join-Path $agentDir 'codex-plan.out.log'
$errFile    = Join-Path $agentDir 'codex-plan.err.log'
$designPath = Join-Path $agentDir 'DESIGN.md'
$utf8NoBom  = New-Object System.Text.UTF8Encoding($false)

$logDir  = Join-Path $env:USERPROFILE '.dsh\logs'
New-Item -ItemType Directory -Force -Path $logDir -ErrorAction SilentlyContinue | Out-Null
$logFile = Join-Path $logDir 'codex-plan.log'
function Write-Log([string]$msg) {
    Add-Content -Path $logFile -Value ((Get-Date -Format o) + '  ' + $msg) -ErrorAction SilentlyContinue
}

# --- 1. 前置检查（按 -Planner 选规划器） ---------------------------------------
$bin = if ($Planner -eq 'claude') { 'claude' } else { 'codex' }
if (-not (Get-Command $bin -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: $bin 不在 PATH，无法生成计划。" -ForegroundColor Red
    Write-Log "FAIL: $bin not found on PATH"
    exit 3
}

# --- 2. 读 DESIGN.md 元数据（design_version / status；锚定 bullet 形式，防误匹配）--
$designVersion = $null; $designStatus = $null
if (Test-Path $designPath) {
    foreach ($line in (Get-Content $designPath -TotalCount 40 -ErrorAction SilentlyContinue)) {
        if ($line -match '^\s*-\s*design_version:\s*(\S+)') { $designVersion = $Matches[1] }
        elseif ($line -match '^\s*-\s*status:\s*(\S+)') { $designStatus = $Matches[1] }
    }
}

# --- 2.5 -FromDesign fail-closed gate（exit 5 = DESIGN contract invalid） --------
if ($FromDesign) {
    $gateReason = $null
    if (-not (Test-Path $designPath)) { $gateReason = '.agent/DESIGN.md 不存在（先让 DSH 播种模板）' }
    elseif ([string]::IsNullOrWhiteSpace($designVersion)) { $gateReason = 'DESIGN.md 缺少 design_version' }
    elseif ($designStatus -ne 'approved') { $gateReason = "DESIGN.status = '$designStatus'（需要 approved）" }
    if ($gateReason) {
        Write-Host "ERROR: DESIGN contract invalid：$gateReason。旧 PLAN.md 未动。" -ForegroundColor Red
        Write-Log "FAIL: design contract invalid ($gateReason)"
        exit 5
    }
}

# --- 3. 组装 prompt（允许只读检查，禁止修改；输出合同） --------------------------
$contract = @"
输出合同（必须严格遵守）：
- 只输出 Markdown 计划正文，不要输出任何元数据头、前言、总结或 CLI 噪声。
- 每个任务以 `### Task N：<标题>` 开头（N 从 1 递增），任务内包含以下字段：
  Status: TODO / IN_PROGRESS / DONE / BLOCKED
  目标 / 涉及文件 / 依赖（Task N 或 无）/ 风险 / 执行者（DSH agent 或 人工）/ 验收标准
- 标注任务间的依赖顺序。
- 必须原样保留 DESIGN 中的 Acceptance Criteria ID（AC1/AC2/...）：不得新增、删除或重命名 AC。
"@
$readOnlyNote = if ($Planner -eq 'claude') {
    '不要调用任何工具、不要读取或修改文件（DESIGN 内容由脚本内联提供）'
} else {
    '可以读取工作区文件并执行只读检查（如查看目录、git status、git diff、搜索代码）'
}
$prompt = @"
你是项目的顶层设计者。只做设计：$readOnlyNote，
但禁止创建、修改、删除任何文件，禁止执行任何会改变工作区或系统状态、或访问外部网络的操作。
$contract

需求：$Request
"@
if ($FromDesign) {
    if ($Planner -eq 'claude') {
        $designBody = Get-Content $designPath -Raw -Encoding UTF8
        $prompt = "以下是工作区 .agent/DESIGN.md 的完整内容（design_version: $designVersion, status: approved），以此为准，不要臆造其中没有的需求。`n`n--- DESIGN.md ---`n$designBody`n--- END ---`n`n" + $prompt
    } else {
        $prompt = "请先读取工作区 .agent/DESIGN.md（design_version: $designVersion, status: approved），以它为准，不要臆造其中没有的需求。`n`n" + $prompt
    }
}

# --- 4. 调用规划器（先清理 stale 输出） ----------------------------------------
Remove-Item $outFile -Force -ErrorAction SilentlyContinue
Remove-Item $errFile -Force -ErrorAction SilentlyContinue

$codexVersion = $null; $claudeVersion = $null
if ($Planner -eq 'claude') {
    Write-Host 'Claude（→DeepSeek）生成中（read-only 由 runtime 强制）……'
    # PS 5.1 双编码：stdin 传中文 prompt（绕开 .cmd shim 参数转码坑），stdout 按 UTF-8 捕获
    $OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $claudeVersion = (& claude --version 2>$null | Select-Object -First 1)   # 本地命令，不消耗额度
    Push-Location $ws
    try {
        # 只读硬保证：--tools= 禁用所有内置工具（等价 --tools ""，= 空值绕开 PS5.1 吞空串）；
        # --bare 跳过 hooks/skills/plugins/MCP/CLAUDE.md 自动发现，保证 fresh-context 规划。
        $stdout = $prompt | & claude --bare -p --tools= --output-format text 2>$errFile
        $exit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($stdout) {
        $text = ($stdout | ForEach-Object { $_.ToString() }) -join "`n"
        [System.IO.File]::WriteAllText($outFile, $text, $utf8NoBom)
    }
} else {
    Write-Host 'Codex 生成中（只读沙箱）……'
    $codexArgs = @(
        'exec',
        '-C', $ws,
        '--skip-git-repo-check',
        '--sandbox', 'read-only',
        '-c', 'approval_policy=never',
        '--output-last-message', $outFile
    )
    $codexVersion = (& codex --version 2>$null | Select-Object -First 1)   # 本地命令，不消耗额度
    $merged = & codex @codexArgs $prompt 2>&1
    $exit = $LASTEXITCODE
    if ($merged) {
        $text = ($merged | ForEach-Object { $_.ToString() }) -join "`n"
        [System.IO.File]::WriteAllText($errFile, $text, $utf8NoBom)   # 显式 UTF-8，避免 5.1 的 2> 写成 UTF-16LE
    }
}
if ($exit -ne 0) {
    $errTail = if (Test-Path $errFile) { ((Get-Content $errFile -Tail 5 -ErrorAction SilentlyContinue) -join ' | ') } else { '' }
    Write-Host "ERROR: $bin 退出码 $exit。旧 PLAN.md 未动。stderr 尾部：$errTail" -ForegroundColor Red
    Write-Log "FAIL: $bin exit=$exit; stderr_tail=$errTail"
    exit 1
}
# exit 0 但没产出文件 = 异常成功，按校验失败处理（旧 PLAN 保留）
if (-not (Test-Path $outFile)) {
    Write-Host "ERROR: $bin 退出码 0 但未产出输出。旧 PLAN.md 未动。" -ForegroundColor Red
    Write-Log "FAIL: $bin exited 0 but no output"
    exit 2
}

# --- 5. 输出校验（防空输出 / 道歉信 / 半截计划 / 违反输出合同） ------------------
$body = Get-Content $outFile -Raw -Encoding UTF8
$valid = $true; $reason = ''
$requiredFields = @('Status:', '目标', '涉及文件', '验收标准')
if ([string]::IsNullOrWhiteSpace($body))            { $valid = $false; $reason = '输出为空' }
elseif ($body.Length -lt 100)                        { $valid = $false; $reason = '输出过短（疑似失败残留）' }
elseif ($body -notmatch '(?m)^#{1,3}\s')             { $valid = $false; $reason = '没有 Markdown 标题结构，不像计划' }
elseif ($body -notmatch '(?m)^#{1,4}\s*Task\s*\d')   { $valid = $false; $reason = '不符合输出合同：找不到 `### Task N` 任务块' }
else {
    # 逐 Task 校验：每个 Task 块必须含四字段（而非全文出现一次即过）
    $blocks = [regex]::Split($body, '(?m)^(?=#{1,4}\s*Task\s*\d)')
    foreach ($block in $blocks) {
        if ($block -notmatch '(?m)^#{1,4}\s*Task\s*\d') { continue }   # 跳过 Task 前的零碎 preamble
        foreach ($field in $requiredFields) {
            if ($block -notmatch [regex]::Escape($field)) {
                $valid = $false
                $reason = "某 Task 块缺少必填字段：$field"
                break
            }
        }
        if (-not $valid) { break }
    }
    # -FromDesign：AC id 集合必须与 DESIGN 一致（不得新增/删除/重命名 AC）
    if ($valid -and $FromDesign -and (Test-Path $designPath)) {
        $designRaw = Get-Content $designPath -Raw -Encoding UTF8
        $designAcs = @([regex]::Matches($designRaw, '\bAC\d+\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
        if ($designAcs.Count -gt 0) {
            $planAcs = @([regex]::Matches($body, '\bAC\d+\b') | ForEach-Object { $_.Value } | Sort-Object -Unique)
            $missing = @($designAcs | Where-Object { $planAcs -notcontains $_ })
            $extra   = @($planAcs | Where-Object { $designAcs -notcontains $_ })
            if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
                $valid = $false
                $reason = "AC 集合不一致：DESIGN=[$($designAcs -join ' ')] PLAN=[$($planAcs -join ' ')] 缺失=[$($missing -join ' ')] 多出=[$($extra -join ' ')]"
            }
        }
    }
}
if (-not $valid) {
    Write-Host "ERROR: $bin 输出未通过校验（$reason）。旧 PLAN.md 未动。" -ForegroundColor Red
    Write-Log "FAIL: validation ($reason); body_len=$($body.Length)"
    exit 2
}

# --- 6. 组装最终 PLAN.md：脚本注入 Metadata 头，正文在后 -------------------------
$now = Get-Date
$planId = 'plan-' + $now.ToString('yyyyMMdd-HHmmssfff')
$cfgModel = '(未读取到)'
if ($Planner -eq 'claude') {
    $cls = Join-Path $env:USERPROFILE '.claude\settings.json'
    if (Test-Path $cls) {
        try {
            $j = Get-Content $cls -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($j.model) { $cfgModel = [string]$j.model }
        } catch { $cfgModel = '(解析失败)' }
    }
    $gby = "claude-cli (configured_model: $cfgModel"
    if ($claudeVersion) { $gby += "; claude: $claudeVersion" }
    $gby += '; note: configured label，可能经第三方路由，不代表实际底层模型)'
} else {
    $codexCfg = Join-Path $env:USERPROFILE '.codex\config.toml'
    if (Test-Path $codexCfg) {
        $m = Select-String -Path $codexCfg -Pattern '^\s*model\s*=\s*"([^"]+)"' | Select-Object -First 1
        if ($m) { $cfgModel = $m.Matches[0].Groups[1].Value }
    }
    $gby = "codex-cli (configured_model: $cfgModel"
    if ($codexVersion) { $gby += "; codex: $codexVersion" }
    $gby += ')'
}
$dv = if ($designVersion) { $designVersion } else { '(DESIGN.md 未填)' }
$ds = if ($designStatus) { $designStatus } else { 'n/a' }
$meta = @"
# PLAN

> 由 plan 脚本生成（脚本 v3.1 / 协议 v2.2，规划器：$Planner）。执行前必须把 status 改为 approved；DSH 只执行 approved 的计划。

## Metadata

- plan_id: $planId
- design_version: $dv
- design_status: $ds
- generated_by: $gby
- generated_at: $($now.ToString('yyyy-MM-ddTHH:mm:sszzz'))
- status: draft
"@
$final = $meta + "`n`n" + $body.Trim() + "`n"

# --- 7. 原子写：tmp → [IO.File]::Replace（替换 + 备份一步完成，失败即失败） ------
try {
    [System.IO.File]::WriteAllText($tmp, $final, $utf8NoBom)
} catch {
    Write-Host "ERROR: 写临时文件失败：$_" -ForegroundColor Red
    Write-Log "FAIL: write tmp: $_"
    exit 4
}
if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
    Write-Host 'ERROR: 临时文件为空，中止替换。' -ForegroundColor Red
    Write-Log 'FAIL: tmp empty, abort'
    exit 4
}
try {
    if (Test-Path $plan) {
        # replacement semantics：tmp 原子地换成 plan，旧 plan 落到 bak（bak 已存在会被覆盖，无需预删）
        [System.IO.File]::Replace($tmp, $plan, $bak)
    } else {
        [System.IO.File]::Move($tmp, $plan)
    }
} catch {
    # 无 fallback：失败就是失败，旧 PLAN 保持不变（合同保证）
    Write-Host "ERROR: 替换 PLAN.md 失败，旧 PLAN 保持不变：$_" -ForegroundColor Red
    Write-Log "FAIL: replace plan: $_"
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    exit 4
}

# --- 8. 收尾 --------------------------------------------------------------------
$bytes = (Get-Item $plan).Length
Write-Host "OK: 已生成 $($plan)（$bytes 字节，plan_id=$planId，design_version=$dv，status=draft）"
Write-Log "OK: plan regenerated; ws=$ws; plan_id=$planId; design_version=$dv; bytes=$bytes; generated_by=$gby"
exit 0
