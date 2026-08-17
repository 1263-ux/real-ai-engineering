[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter = 'D',
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'SilentlyContinue'
$driveRoot = "$($DriveLetter.ToUpper()):\"
if (-not (Test-Path -LiteralPath $driveRoot)) {
    throw "Drive not found: $driveRoot"
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($DriveLetter.ToUpper()):'"
$topLevel = Get-ChildItem -LiteralPath $driveRoot -Force | ForEach-Object {
    [pscustomobject]@{
        Name = $_.Name
        FullName = $_.FullName
        IsDirectory = $_.PSIsContainer
        Attributes = $_.Attributes.ToString()
        Length = if ($_.PSIsContainer) { $null } else { $_.Length }
        LastWriteTime = $_.LastWriteTime
    }
}

$wsh = New-Object -ComObject WScript.Shell
$shortcutRoots = @(
    [Environment]::GetFolderPath('Desktop'),
    "$env:PUBLIC\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu",
    "$env:ProgramData\Microsoft\Windows\Start Menu"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
$shortcuts = foreach ($root in $shortcutRoots) {
    Get-ChildItem -LiteralPath $root -Filter '*.lnk' -File -Recurse -Force | ForEach-Object {
        $link = $wsh.CreateShortcut($_.FullName)
        [pscustomobject]@{
            Link = $_.FullName
            Target = $link.TargetPath
            TargetExists = if ($link.TargetPath) { Test-Path -LiteralPath $link.TargetPath } else { $false }
            WorkingDirectory = $link.WorkingDirectory
            IconLocation = $link.IconLocation
        }
    }
}

$pathEntries = foreach ($scope in 'User','Machine') {
    $raw = [Environment]::GetEnvironmentVariable('Path', $scope)
    foreach ($entry in ($raw -split ';' | Where-Object { $_ })) {
        $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim())
        [pscustomobject]@{
            Scope = $scope
            Entry = $entry.Trim()
            Expanded = $expanded
            Exists = if ($expanded -match '^[A-Za-z]:\') { Test-Path -LiteralPath $expanded } else { $true }
        }
    }
}

$sensitivePattern = '(?i)(secret|token|password|passwd|credential|access[_-]?key|api[_-]?key)'
$environment = foreach ($scope in 'User','Machine') {
    $key = if ($scope -eq 'User') {
        'HKCU:\Environment'
    } else {
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    }
    if (Test-Path $key) {
        (Get-ItemProperty $key).PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS' } |
            ForEach-Object {
                [pscustomobject]@{
                    Scope = $scope
                    Name = $_.Name
                    Value = if ($_.Name -match $sensitivePattern) { '<redacted-present>' } else { [string]$_.Value }
                }
            }
    }
}

$uninstallRoots = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$applications = Get-ItemProperty $uninstallRoots | Where-Object DisplayName | ForEach-Object {
    [pscustomobject]@{
        DisplayName = $_.DisplayName
        DisplayVersion = $_.DisplayVersion
        InstallLocation = $_.InstallLocation
        DisplayIcon = $_.DisplayIcon
        UninstallString = $_.UninstallString
    }
}

$vhdx = Get-ChildItem -LiteralPath $driveRoot -Filter '*.vhdx' -File -Recurse -Force | ForEach-Object {
    [pscustomobject]@{
        FullName = $_.FullName
        Length = $_.Length
        LastWriteTime = $_.LastWriteTime
    }
}

$report = [ordered]@{
    SchemaVersion = 1
    CreatedAt = (Get-Date).ToString('o')
    ReadOnlyInventory = $true
    Drive = [ordered]@{
        Root = $driveRoot
        Size = $logical.Size
        FreeSpace = $logical.FreeSpace
    }
    TopLevel = $topLevel
    Shortcuts = $shortcuts
    PathEntries = $pathEntries
    Environment = $environment
    InstalledApplications = $applications
    VirtualDiskFiles = $vhdx
}

$jsonPath = Join-Path $resolvedOutput "drive-inventory-$timestamp.json"
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$jsonPath

