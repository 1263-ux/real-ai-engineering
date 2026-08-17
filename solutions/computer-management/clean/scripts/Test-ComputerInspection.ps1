[CmdletBinding()]
param(
    [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $ProjectRoot 'clean\scripts\Invoke-ComputerInspection.ps1'
$configPath = Join-Path $ProjectRoot 'clean\config\inspection-config.json'
$testReportRoot = Join-Path $ProjectRoot '06-维护日志\周期巡检\测试'
$testRawRoot = Join-Path $ProjectRoot 'maintenance\periodic\tests'
New-Item -ItemType Directory -Force -Path $testReportRoot, $testRawRoot | Out-Null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$parseErrors)
Assert-True ($parseErrors.Count -eq 0) 'Runner has PowerShell parse errors.'

$commandNames = $ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true) |
    ForEach-Object { $_.GetCommandName() } | Where-Object { $_ }
$bannedCommands = @(
    'Remove-Item', 'Move-Item', 'Rename-Item', 'Clear-Content',
    'Set-ItemProperty', 'New-ItemProperty', 'Remove-ItemProperty',
    'Start-Service', 'Stop-Service', 'Restart-Service', 'Stop-Process'
)
foreach ($name in $bannedCommands) {
    Assert-True ($name -notin $commandNames) "Runner contains forbidden command: $name"
}

$runnerText = Get-Content -LiteralPath $runner -Encoding utf8 -Raw
foreach ($pattern in 'docker system prune', 'wsl --unregister', 'diskpart clean', 'format.com') {
    Assert-True ($runnerText -notmatch [regex]::Escape($pattern)) "Runner contains forbidden operation text: $pattern"
}

$overlap = & $runner -Mode weekly -ReferenceTime ([datetime]'2027-01-01T18:00:00') -ReportRoot $testReportRoot -RawRoot $testRawRoot
Assert-True ([bool]$overlap.Skipped) 'Weekly inspection did not skip on a monthly inspection date.'
Assert-True (Test-Path -LiteralPath $overlap.ReportPath) 'Overlap report was not written.'
Assert-True (Test-Path -LiteralPath $overlap.RawPath) 'Overlap raw JSON was not written.'

$fixture = Get-Content -LiteralPath $configPath -Encoding utf8 -Raw | ConvertFrom-Json
$fixture.CriticalPaths[0] = 'Q:\__computer_inspection_missing_path__'
$fixturePath = Join-Path $testRawRoot 'missing-path-config.json'
$fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixturePath -Encoding UTF8
$missing = & $runner -Mode weekly -ReferenceTime ([datetime]'2026-08-07T18:00:00') -ConfigPath $fixturePath -ReportRoot $testReportRoot -RawRoot $testRawRoot
Assert-True ($missing.Status -eq '需处理') 'Missing critical path was not classified as needs action.'

$raw = Get-Content -LiteralPath $missing.RawPath -Encoding utf8 -Raw | ConvertFrom-Json
Assert-True (-not $raw.Safety.SystemStateModified) 'Raw result claims system state was modified.'
Assert-True (-not $raw.Safety.DeletionPerformed) 'Raw result claims deletion was performed.'
Assert-True (-not $raw.Safety.RepairPerformed) 'Raw result claims repair was performed.'

$reportText = Get-Content -LiteralPath $missing.ReportPath -Encoding utf8 -Raw
$sensitivePattern = '(?i)(secret|token|password|passwd|credential|access[_-]?key|api[_-]?key)'
foreach ($scope in 'Process', 'User', 'Machine') {
    foreach ($entry in [Environment]::GetEnvironmentVariables($scope).GetEnumerator()) {
        if ([string]$entry.Key -match $sensitivePattern -and [string]$entry.Value) {
            Assert-True (-not $reportText.Contains([string]$entry.Value)) "Report exposed a sensitive environment value: $($entry.Key)"
        }
    }
}

[pscustomobject]@{
    Passed = $true
    ParseCheck = 'passed'
    SafetyCheck = 'passed'
    OverlapCheck = 'passed'
    MissingPathCheck = 'passed'
    SecretRedactionCheck = 'passed'
    TestReportRoot = $testReportRoot
    TestRawRoot = $testRawRoot
}
