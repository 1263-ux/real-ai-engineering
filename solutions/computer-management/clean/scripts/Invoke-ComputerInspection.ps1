[CmdletBinding()]
param(
    [ValidateSet('weekly', 'monthly', 'quarterly', 'yearly')]
    [string]$Mode = 'weekly',
    [string]$ConfigPath,
    [string]$ProjectRoot,
    [string]$ReportRoot,
    [string]$RawRoot,
    [datetime]$ReferenceTime = (Get-Date)
)

$ErrorActionPreference = 'Stop'
$script:results = [System.Collections.Generic.List[object]]::new()
$script:writtenFiles = [System.Collections.Generic.List[string]]::new()
$startedAt = Get-Date

function Add-Result {
    param(
        [string]$Area,
        [string]$Name,
        [ValidateSet('Pass', 'Attention', 'Action', 'Incomplete', 'Info')]
        [string]$Level,
        [string]$Evidence
    )
    $script:results.Add([pscustomobject]@{
        Area = $Area
        Name = $Name
        Level = $Level
        Evidence = $Evidence
    })
}

function Get-ModeLabel {
    param([string]$Value)
    switch ($Value) {
        'weekly' { '周巡检' }
        'monthly' { '月度盘点' }
        'quarterly' { '季度总审视' }
        'yearly' { '年度总报告' }
    }
}

function Get-ReportFolderName {
    param([string]$Value)
    switch ($Value) {
        'weekly' { '周报' }
        'monthly' { '月报' }
        'quarterly' { '季报' }
        'yearly' { '年报' }
    }
}

function Get-HigherPriorityMode {
    param([datetime]$Date)
    if ($Date.Month -eq 1 -and $Date.Day -eq 10) { return 'yearly' }
    if ($Date.Month -in 1, 4, 7, 10 -and $Date.Day -eq 5) { return 'quarterly' }
    if ($Date.Day -eq 1) { return 'monthly' }
    return $null
}

function ConvertTo-SafeArgument {
    param([string]$Value)
    "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-ReadOnlyCommand {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [int]$TimeoutSeconds
    )
    $resolved = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) {
        return [pscustomobject]@{ Found = $false; Completed = $true; ExitCode = $null; Output = 'command not found'; Source = $null }
    }

    $commandParts = @('&', (ConvertTo-SafeArgument $resolved.Source))
    $commandParts += $Arguments | ForEach-Object { ConvertTo-SafeArgument $_ }
    $commandText = ($commandParts -join ' ') + '; exit $LASTEXITCODE'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))

    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "$PSHOME\powershell.exe"
    $psi.Arguments = "-NoProfile -NonInteractive -EncodedCommand $encoded"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($variableName in 'UV_CACHE_DIR', 'PIP_CACHE_DIR', 'GRADLE_USER_HOME', 'VOLTA_HOME') {
        $userValue = [Environment]::GetEnvironmentVariable($variableName, 'User')
        if ($userValue) { $psi.EnvironmentVariables[$variableName] = $userValue }
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    try {
        [void]$process.Start()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            return [pscustomobject]@{ Found = $true; Completed = $false; ExitCode = $null; Output = "timeout after $TimeoutSeconds seconds"; Source = $resolved.Source }
        }
        $stdout = $process.StandardOutput.ReadToEnd().Trim()
        $stderr = $process.StandardError.ReadToEnd().Trim()
        $output = (@($stdout, $stderr) | Where-Object { $_ }) -join "`n"
        return [pscustomobject]@{ Found = $true; Completed = $true; ExitCode = $process.ExitCode; Output = $output; Source = $resolved.Source }
    } catch {
        return [pscustomobject]@{ Found = $true; Completed = $false; ExitCode = $null; Output = $_.Exception.Message; Source = $resolved.Source }
    } finally {
        $process.Dispose()
    }
}

function Get-PathFromOutput {
    param([string]$Output)
    foreach ($line in ($Output -split "`r?`n")) {
        $candidate = $line.Trim()
        if ($candidate -match '^[A-Za-z]:\\') { return $candidate }
    }
    return $null
}

function Test-ExpectedPathPrefix {
    param([string]$Actual, [string]$Expected)
    try {
        $actualPath = [IO.Path]::GetFullPath($Actual).TrimEnd('\')
        $expectedPath = [IO.Path]::GetFullPath($Expected).TrimEnd('\')
        return $actualPath.StartsWith($expectedPath, [StringComparison]::OrdinalIgnoreCase)
    } catch {
        return $false
    }
}

function Get-OverallStatus {
    if ($script:results.Level -contains 'Action') { return '需处理' }
    if ($script:results.Level -contains 'Incomplete') { return '检查未完成' }
    if ($script:results.Level -contains 'Attention') { return '需注意' }
    return '正常'
}

function Get-PreviousObservation {
    param([string]$Root, [string]$CurrentPath)
    $candidate = Get-ChildItem -LiteralPath $Root -Filter 'inspection-*.json' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $CurrentPath } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $candidate) { return $null }
    try { Get-Content -LiteralPath $candidate.FullName -Encoding utf8 -Raw | ConvertFrom-Json } catch { $null }
}

function Get-MarkdownList {
    param([object[]]$Items, [string]$EmptyText)
    if (-not $Items -or $Items.Count -eq 0) { return "- $EmptyText" }
    return ($Items | ForEach-Object { "- **$($_.Name)**：$($_.Evidence)" }) -join "`n"
}

function Write-InspectionIndex {
    param([string]$Root, [datetime]$UpdatedAt)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# 周期巡检索引')
    $lines.Add('')
    $lines.Add("更新时间：$($UpdatedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
    $lines.Add('')
    $lines.Add('自动巡检只读取系统、应用、配置和用户数据；仅写入巡检报告、原始 JSON、周期索引和已验证的维护说明文档。')
    $lines.Add('')
    $lines.Add('| 模式 | 最新报告 |')
    $lines.Add('|---|---|')
    foreach ($item in @(@('weekly','周报'), @('monthly','月报'), @('quarterly','季报'), @('yearly','年报'))) {
        $latest = Get-ChildItem -LiteralPath (Join-Path $Root $item[1]) -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $value = if ($latest) { $latest.FullName } else { '暂无' }
        $lines.Add("| $(Get-ModeLabel $item[0]) | $value |")
    }
    $indexPath = Join-Path $Root 'README.md'
    $lines -join "`n" | Set-Content -LiteralPath $indexPath -Encoding UTF8
    if (-not $script:writtenFiles.Contains($indexPath)) { $script:writtenFiles.Add($indexPath) }
}

function Write-VerifiedState {
    param(
        [string]$Path,
        [string]$Status,
        [datetime]$ObservedAt,
        [object[]]$DriveSummaries,
        [object[]]$CommandResults,
        [object[]]$CacheResults,
        [string]$ReportPath
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# 自动巡检最新状态')
    $lines.Add('')
    $lines.Add("更新时间：$($ObservedAt.ToString('yyyy-MM-dd HH:mm:ss'))")
    $lines.Add('')
    $lines.Add("总体状态：**$Status**")
    $lines.Add('')
    $lines.Add('## 已验证磁盘状态')
    $lines.Add('')
    $lines.Add('| 盘符 | 总容量 | 可用空间 | 空闲率 |')
    $lines.Add('|---|---:|---:|---:|')
    foreach ($drive in $DriveSummaries) {
        $lines.Add("| $($drive.DeviceID) | $($drive.SizeGB) GB | $($drive.FreeGB) GB | $($drive.FreePercent)% |")
    }
    $lines.Add('')
    $lines.Add('## 已验证命令入口')
    $lines.Add('')
    foreach ($command in $CommandResults) { $lines.Add("- $($command.Name)：$($command.State)") }
    $lines.Add('')
    $lines.Add('## 已验证缓存路径')
    $lines.Add('')
    foreach ($cache in $CacheResults) { $lines.Add("- $($cache.Name)：$($cache.State)") }
    $lines.Add('')
    $lines.Add("详细证据：[巡检报告]($ReportPath)")
    $lines.Add('')
    $lines.Add('本文件由月度、季度或年度巡检更新；周巡检不会修改本文件。')
    $lines -join "`n" | Set-Content -LiteralPath $Path -Encoding UTF8
    $script:writtenFiles.Add($Path)
}

if (-not $ProjectRoot) { $ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')) }
if (-not $ConfigPath) { $ConfigPath = Join-Path $ProjectRoot 'clean\config\inspection-config.json' }
if (-not $ReportRoot) { $ReportRoot = Join-Path $ProjectRoot '06-维护日志\周期巡检' }
if (-not $RawRoot) { $RawRoot = Join-Path $ProjectRoot 'maintenance\periodic' }

$config = Get-Content -LiteralPath $ConfigPath -Encoding utf8 -Raw | ConvertFrom-Json
$modeLabel = Get-ModeLabel $Mode
$folderName = Get-ReportFolderName $Mode
$timestamp = $ReferenceTime.ToString('yyyyMMdd-HHmmss')
$reportDirectory = Join-Path $ReportRoot $folderName
$rawDirectory = Join-Path $RawRoot (Join-Path $Mode $timestamp)
New-Item -ItemType Directory -Force -Path $reportDirectory, $rawDirectory | Out-Null
$reportPath = Join-Path $reportDirectory "$timestamp-$Mode.md"
$rawPath = Join-Path $rawDirectory "inspection-$timestamp.json"
$indexPath = Join-Path $ReportRoot 'README.md'
$verifiedStatePath = if ($Mode -in 'monthly', 'quarterly', 'yearly') { Join-Path $ProjectRoot '01-电脑现状\自动巡检最新状态.md' } else { $null }

$higherMode = Get-HigherPriorityMode $ReferenceTime
$skipped = $Mode -eq 'weekly' -and $higherMode
if ($skipped) {
    $reason = "同日安排了更高优先级任务：$(Get-ModeLabel $higherMode)"
    Add-Result 'Schedule' '周巡检跳过' 'Info' $reason
}

$requiredDocuments = @(
    (Join-Path $ProjectRoot 'clean\SKILL.md'),
    (Join-Path $ProjectRoot '01-电脑现状\当前状态.md')
)
foreach ($document in $requiredDocuments) {
    if (Test-Path -LiteralPath $document) {
        [void](Get-Content -LiteralPath $document -Encoding utf8 -Raw)
        Add-Result 'Documentation' $document 'Pass' '已读取'
    } else {
        Add-Result 'Documentation' $document 'Action' '维护基线文档缺失'
    }
}
$logCandidates = @(
    Get-ChildItem -LiteralPath (Join-Path $ProjectRoot '06-维护日志') -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike "$ReportRoot*" }
    Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'maintenance') -Filter '*.md' -File -ErrorAction SilentlyContinue
)
$latestLog = $logCandidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($latestLog) {
    [void](Get-Content -LiteralPath $latestLog.FullName -Encoding utf8 -Raw)
    Add-Result 'Documentation' '最新维护日志' 'Pass' $latestLog.FullName
} else {
    Add-Result 'Documentation' '最新维护日志' 'Action' '没有可读取的维护日志'
}

$driveSummaries = @()
$commandObservations = @()
$cacheObservations = @()
$inventoryPaths = @()

if (-not $skipped) {
    try {
        $driveSummaries = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
            Where-Object { $_.DeviceID -in 'C:', 'D:' } |
            ForEach-Object {
                [pscustomobject]@{
                    DeviceID = $_.DeviceID
                    SizeGB = [math]::Round($_.Size / 1GB, 1)
                    FreeGB = [math]::Round($_.FreeSpace / 1GB, 1)
                    FreePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
                }
            })
        if ($driveSummaries.Count -lt 2) { Add-Result 'Disk' 'C/D 盘' 'Incomplete' '未能取得两个固定磁盘的状态' }
        foreach ($drive in $driveSummaries) {
            $level = if ($drive.FreePercent -lt 10) { 'Action' } elseif ($drive.FreePercent -lt 20) { 'Attention' } else { 'Pass' }
            Add-Result 'Disk' $drive.DeviceID $level "$($drive.FreeGB) GB 可用（$($drive.FreePercent)%）"
        }
    } catch {
        Add-Result 'Disk' 'C/D 盘' 'Incomplete' $_.Exception.Message
    }

    foreach ($command in $config.Commands) {
        $result = Invoke-ReadOnlyCommand -Name $command.Name -Arguments @($command.Arguments) -TimeoutSeconds $config.CommandTimeoutSeconds
        if (-not $result.Found) {
            $level = if ($command.Critical) { 'Action' } else { 'Attention' }
            Add-Result 'Command' $command.Name $level '命令未找到'
            $commandObservations += [pscustomobject]@{ Name = $command.Name; State = '未找到' }
        } elseif (-not $result.Completed) {
            Add-Result 'Command' $command.Name 'Incomplete' $result.Output
            $commandObservations += [pscustomobject]@{ Name = $command.Name; State = '未验证' }
        } elseif ($result.ExitCode -ne 0) {
            $level = if ($command.Critical) { 'Action' } else { 'Attention' }
            Add-Result 'Command' $command.Name $level "退出码 $($result.ExitCode)：$($result.Output)"
            $commandObservations += [pscustomobject]@{ Name = $command.Name; State = "异常（$($result.ExitCode)）" }
        } else {
            $versionText = if ($command.Name -eq 'wsl') { '命令可执行；发行版停止状态不视为故障' } else { (($result.Output -split "`r?`n") | Select-Object -First 2) -join ' / ' }
            Add-Result 'Command' $command.Name 'Pass' "$($result.Source)；$versionText"
            $commandObservations += [pscustomobject]@{ Name = $command.Name; State = $versionText }
        }
    }

    foreach ($cache in $config.CacheChecks) {
        $result = Invoke-ReadOnlyCommand -Name $cache.Command -Arguments @($cache.Arguments) -TimeoutSeconds $config.CommandTimeoutSeconds
        $actualPath = if ($result.Completed -and $result.ExitCode -eq 0) { Get-PathFromOutput $result.Output } else { $null }
        if (-not $actualPath) {
            Add-Result 'Cache' $cache.Name 'Incomplete' '缓存路径无法确认，标记为未验证'
            $cacheObservations += [pscustomobject]@{ Name = $cache.Name; State = '未验证' }
        } elseif (Test-ExpectedPathPrefix $actualPath $cache.ExpectedPath) {
            Add-Result 'Cache' $cache.Name 'Pass' $actualPath
            $cacheObservations += [pscustomobject]@{ Name = $cache.Name; State = $actualPath }
        } else {
            Add-Result 'Cache' $cache.Name 'Attention' "当前为 $actualPath；预期位于 $($cache.ExpectedPath)"
            $cacheObservations += [pscustomobject]@{ Name = $cache.Name; State = "疑似漂移：$actualPath" }
        }
    }

    foreach ($path in $config.CriticalPaths) {
        Add-Result 'CriticalPath' $path $(if (Test-Path -LiteralPath $path) { 'Pass' } else { 'Action' }) $(if (Test-Path -LiteralPath $path) { '路径存在' } else { '关键路径缺失' })
    }
    foreach ($path in $config.VirtualDiskPaths) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            Add-Result 'VirtualDisk' $path 'Pass' "$([math]::Round($item.Length / 1GB, 2)) GB"
        } else {
            Add-Result 'VirtualDisk' $path 'Action' '虚拟磁盘缺失'
        }
    }
    foreach ($path in $config.UserEntries) {
        Add-Result 'UserEntry' $path $(if (Test-Path -LiteralPath $path) { 'Pass' } else { 'Attention' }) $(if (Test-Path -LiteralPath $path) { '入口存在' } else { '入口不存在或无法确认' })
    }

    try {
        $wsh = New-Object -ComObject WScript.Shell
        $desktop = [Environment]::GetFolderPath('Desktop')
        foreach ($shortcut in Get-ChildItem -LiteralPath $desktop -Filter '*.lnk' -File -ErrorAction SilentlyContinue) {
            $link = $wsh.CreateShortcut($shortcut.FullName)
            if ($link.TargetPath -and $link.TargetPath -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $link.TargetPath)) {
                Add-Result 'Shortcut' $shortcut.FullName 'Attention' "目标不存在：$($link.TargetPath)"
            }
        }
        Add-Result 'Shortcut' '桌面快捷方式' 'Pass' '仅检查具有明确文件目标的快捷方式；空目标不判定为故障'
    } catch {
        Add-Result 'Shortcut' '桌面快捷方式' 'Incomplete' $_.Exception.Message
    }

    $eventDays = if ($Mode -eq 'weekly') { 7 } else { 30 }
    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = $ReferenceTime.AddDays(-$eventDays) } -ErrorAction Stop)
        $groups = $events | Group-Object ProviderName, Id | Sort-Object Count -Descending
        foreach ($group in $groups | Select-Object -First 8) {
            $sample = $group.Group | Select-Object -First 1
            $isNoise = $config.NoiseEvents | Where-Object { $_.Provider -eq $sample.ProviderName -and $_.Id -eq $sample.Id }
            if ($isNoise) {
                Add-Result 'Event' "$($sample.ProviderName)/$($sample.Id)" 'Info' "$($group.Count) 次；已知噪声，仅统计"
            } else {
                Add-Result 'Event' "$($sample.ProviderName)/$($sample.Id)" 'Attention' "$($group.Count) 次；最近：$($sample.TimeCreated)"
            }
        }
        if ($groups.Count -eq 0) { Add-Result 'Event' '系统错误事件' 'Pass' "最近 $eventDays 天没有严重或错误事件" }
    } catch {
        Add-Result 'Event' '系统错误事件' 'Incomplete' $_.Exception.Message
    }

    if ($Mode -in 'monthly', 'quarterly', 'yearly') {
        foreach ($scope in 'User', 'Machine') {
            $scopePath = [Environment]::GetEnvironmentVariable('Path', $scope)
            foreach ($entry in ($scopePath -split ';' | Where-Object { $_ })) {
                $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim())
                if ($expanded -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $expanded)) {
                    Add-Result 'PATH' "$scope PATH" 'Attention' "无效候选：$entry"
                }
            }
        }

        $inventoryScript = Join-Path $ProjectRoot 'clean\scripts\Get-DriveInventory.ps1'
        foreach ($letter in 'C', 'D') {
            try {
                $driveOutput = Join-Path $rawDirectory $letter
                $inventoryPath = & $inventoryScript -DriveLetter $letter -OutputDirectory $driveOutput
                $inventoryPaths += $inventoryPath
                Add-Result 'Inventory' "$letter 盘结构盘点" 'Pass' $inventoryPath
                $script:writtenFiles.Add($inventoryPath)
            } catch {
                Add-Result 'Inventory' "$letter 盘结构盘点" 'Incomplete' $_.Exception.Message
            }
        }
    }

    if ($Mode -in 'quarterly', 'yearly') {
        foreach ($document in $config.RecoveryDocuments) {
            Add-Result 'Recovery' $document $(if (Test-Path -LiteralPath $document) { 'Pass' } else { 'Action' }) $(if (Test-Path -LiteralPath $document) { '恢复说明可读' } else { '恢复说明缺失' })
        }

        try {
            $appPathRoots = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths')
            foreach ($root in $appPathRoots) {
                foreach ($key in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue) {
                    $value = $key.GetValue('')
                    if ($value -and $value -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath ($value.Trim('"')))) {
                        Add-Result 'AppPaths' $key.PSChildName 'Attention' "登记路径不存在：$value"
                    }
                }
            }
            Add-Result 'AppPaths' '应用注册入口' 'Pass' '完成绝对路径检查；历史登记仅列候选'
        } catch {
            Add-Result 'AppPaths' '应用注册入口' 'Incomplete' $_.Exception.Message
        }

        try {
            foreach ($service in Get-CimInstance Win32_Service) {
                $binary = $null
                if ($service.PathName -match '^\s*"([^"]+\.exe)"') { $binary = $matches[1] }
                elseif ($service.PathName -match '^\s*(.+?\.exe)\b') { $binary = $matches[1] }
                if ($binary -and $binary -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $binary)) {
                    Add-Result 'Service' $service.Name 'Attention' "服务程序不存在：$binary"
                }
            }
            Add-Result 'Service' '服务程序路径' 'Pass' '完成可解析绝对路径检查'
        } catch {
            Add-Result 'Service' '服务程序路径' 'Incomplete' $_.Exception.Message
        }

        try {
            foreach ($task in Get-ScheduledTask -ErrorAction Stop) {
                foreach ($action in $task.Actions) {
                    $execute = [Environment]::ExpandEnvironmentVariables([string]$action.Execute)
                    if ($execute -match '^[A-Za-z]:\\' -and -not (Test-Path -LiteralPath $execute)) {
                        Add-Result 'ScheduledTask' $task.TaskName 'Attention' "任务程序不存在：$execute"
                    }
                }
            }
            Add-Result 'ScheduledTask' '计划任务入口' 'Pass' '完成绝对路径检查'
        } catch {
            Add-Result 'ScheduledTask' '计划任务入口' 'Incomplete' $_.Exception.Message
        }

        $vmRoot = $config.ScanRoots.VirtualMachineRoot
        $vmx = @(Get-ChildItem -LiteralPath $vmRoot -Filter '*.vmx' -File -Recurse -ErrorAction SilentlyContinue)
        $vmdk = @(Get-ChildItem -LiteralPath $vmRoot -Filter '*.vmdk' -File -Recurse -ErrorAction SilentlyContinue)
        Add-Result 'VMware' 'VMX 文件' $(if ($vmx.Count -gt 0) { 'Pass' } else { 'Action' }) "$($vmx.Count) 个"
        Add-Result 'VMware' 'VMDK 文件' $(if ($vmdk.Count -gt 0) { 'Pass' } else { 'Action' }) "$($vmdk.Count) 个"

        $compose = @()
        foreach ($root in $config.ScanRoots.DockerComposeRoots) {
            if (Test-Path -LiteralPath $root) {
                $compose += Get-ChildItem -LiteralPath $root -Include 'compose*.yml', 'compose*.yaml', 'docker-compose*.yml', 'docker-compose*.yaml' -File -Recurse -ErrorAction SilentlyContinue
            }
        }
        Add-Result 'Docker' 'Compose 项目文件' $(if ($compose.Count -gt 0) { 'Pass' } else { 'Attention' }) "$($compose.Count) 个；未启动 Docker"

        $wslResult = Invoke-ReadOnlyCommand -Name 'wsl' -Arguments @('--list', '--verbose') -TimeoutSeconds $config.CommandTimeoutSeconds
        if ($wslResult.Completed -and $wslResult.ExitCode -eq 0) {
            Add-Result 'WSL' '发行版登记' 'Pass' '查询成功；停止状态不视为故障'
        } else {
            Add-Result 'WSL' '发行版登记' 'Incomplete' $wslResult.Output
        }

        $installerRoot = $config.ScanRoots.InstallerRoot
        if (Test-Path -LiteralPath $installerRoot) {
            $oldInstallers = @(Get-ChildItem -LiteralPath $installerRoot -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $ReferenceTime.AddDays(-90) })
            if ($oldInstallers.Count -gt 0) {
                Add-Result 'Candidate' '旧安装包' 'Info' "$($oldInstallers.Count) 个，仅列候选；删除需用户确认"
            }
        }
        Add-Result 'SystemMaintenance' '管理员级系统检查' 'Info' '可人工安排 DISM /ScanHealth、SFC /verifyonly、CHKDSK /scan；自动任务不执行'
    }

    if ($Mode -eq 'yearly') {
        $maintenanceLogs = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot '06-维护日志') -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue)
        $backupItems = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot '07-备份与恢复') -Directory -ErrorAction SilentlyContinue)
        Add-Result 'AnnualBaseline' '维护日志' $(if ($maintenanceLogs.Count -gt 0) { 'Pass' } else { 'Action' }) "$($maintenanceLogs.Count) 份"
        Add-Result 'AnnualBaseline' '备份目录' $(if ($backupItems.Count -gt 0) { 'Pass' } else { 'Action' }) "$($backupItems.Count) 个"
    }
}

foreach ($item in @(@('weekly','周报'), @('monthly','月报'), @('quarterly','季报'), @('yearly','年报'))) {
    $limit = [int]$config.Retention.($item[0])
    if ($limit -gt 0) {
        $reports = @(Get-ChildItem -LiteralPath (Join-Path $ReportRoot $item[1]) -Filter '*.md' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
        if ($reports.Count -gt $limit) {
            Add-Result 'Retention' "$($item[1])超期候选" 'Info' "$($reports.Count - $limit) 份；不自动删除"
        }
    }
}

$status = Get-OverallStatus
$previous = Get-PreviousObservation -Root $RawRoot -CurrentPath $rawPath
$changes = [System.Collections.Generic.List[string]]::new()
if ($previous -and $previous.DriveSummaries) {
    foreach ($drive in $driveSummaries) {
        $old = $previous.DriveSummaries | Where-Object DeviceID -eq $drive.DeviceID | Select-Object -First 1
        if ($old) {
            $delta = [math]::Round($drive.FreeGB - $old.FreeGB, 1)
            if ([math]::Abs($delta) -ge 1) { $changes.Add("$($drive.DeviceID) 可用空间变化 $delta GB") }
        }
    }
}
foreach ($item in $script:results | Where-Object { $_.Level -in 'Action', 'Incomplete', 'Attention' } | Select-Object -First 5) {
    if (-not $changes.Contains("$($item.Name)：$($item.Evidence)")) { $changes.Add("$($item.Name)：$($item.Evidence)") }
}

$observation = [ordered]@{
    SchemaVersion = 1
    Mode = $Mode
    ModeLabel = $modeLabel
    CreatedAt = $ReferenceTime.ToString('o')
    CompletedAt = (Get-Date).ToString('o')
    Status = $status
    Skipped = [bool]$skipped
    DriveSummaries = $driveSummaries
    CommandObservations = $commandObservations
    CacheObservations = $cacheObservations
    Results = $script:results
    InventoryPaths = $inventoryPaths
    Safety = [ordered]@{
        SystemStateModified = $false
        DeletionPerformed = $false
        RepairPerformed = $false
        AllowedWrites = @('inspection report', 'raw JSON', 'periodic index', 'verified state document')
    }
}
$observation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rawPath -Encoding UTF8
$script:writtenFiles.Add($rawPath)

$completed = @($script:results | Where-Object { $_.Level -in 'Pass', 'Info' })
$incomplete = @($script:results | Where-Object Level -eq 'Incomplete')
$actionItems = @($script:results | Where-Object Level -eq 'Action')
$attentionItems = @($script:results | Where-Object Level -eq 'Attention')
$infoItems = @($script:results | Where-Object Level -eq 'Info')
$duration = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)

$report = @"
# $($ReferenceTime.ToString('yyyy-MM-dd HH:mm:ss')) $modeLabel

## 巡检结果

- 总体状态：**$status**
- 检查模式：$Mode
- 耗时：$duration 秒
- 是否跳过：$([bool]$skipped)

## 主要变化

$(if ($changes.Count) { ($changes | Select-Object -First 5 | ForEach-Object { "- $_" }) -join "`n" } else { '- 没有足够的历史证据形成变化结论。' })

## 已完成检查

$(Get-MarkdownList $completed '没有完成项。')

## 未完成或无权限检查

$(Get-MarkdownList $incomplete '无。')

## 发现的问题

$(Get-MarkdownList (@($actionItems + $attentionItems)) '没有发现需要处理或注意的问题。')

## 需要人工确认

$(if ($actionItems.Count -or $attentionItems.Count) { '- 如需修复、移动、清理、删除或管理员操作，必须另开维护任务并由用户确认精确目标、风险、备份和恢复方法。' } else { '- 无。' })

## 建议处理

$(Get-MarkdownList $actionItems '无。')

## 建议观察

$(Get-MarkdownList $attentionItems '无。')

## 建议忽略

$(Get-MarkdownList $infoItems '无。')

## 本次写入

$(($(@($reportPath, $rawPath, $indexPath) + $inventoryPaths + @($verifiedStatePath | Where-Object { $_ })) | ForEach-Object { "- $_" }) -join "`n")

## 安全声明

本次巡检只读取系统、应用、配置和用户数据；仅写入巡检报告、原始 JSON、周期索引和允许的已验证状态说明。未删除、移动、清理、修复、安装、卸载、启停工作负载、修改配置或请求管理员权限。
"@
$report | Set-Content -LiteralPath $reportPath -Encoding UTF8
$script:writtenFiles.Add($reportPath)

if (-not $skipped -and $Mode -in 'monthly', 'quarterly', 'yearly') {
    Write-VerifiedState -Path $verifiedStatePath -Status $status -ObservedAt $ReferenceTime -DriveSummaries $driveSummaries -CommandResults $commandObservations -CacheResults $cacheObservations -ReportPath $reportPath
}

Write-InspectionIndex -Root $ReportRoot -UpdatedAt $ReferenceTime

[pscustomobject]@{
    Mode = $Mode
    Status = $status
    Skipped = [bool]$skipped
    ReportPath = $reportPath
    RawPath = $rawPath
    WrittenFiles = @($script:writtenFiles)
}
