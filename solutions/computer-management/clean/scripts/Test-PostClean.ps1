[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter = 'D',
    [string[]]$CriticalPaths = @(),
    [string[]]$Commands = @('git','java','node','python','docker','wsl'),
    [string]$InventoryPath
)

$ErrorActionPreference = 'SilentlyContinue'
$driveRoot = "$($DriveLetter.ToUpper()):\"
$checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
    param([string]$Area,[string]$Name,[bool]$Passed,[string]$Evidence)
    $checks.Add([pscustomobject]@{
        Area = $Area
        Name = $Name
        Passed = $Passed
        Evidence = $Evidence
    })
}

Add-Check 'Drive' $driveRoot (Test-Path -LiteralPath $driveRoot) 'Drive root exists'

foreach ($path in $CriticalPaths) {
    Add-Check 'CriticalPath' $path (Test-Path -LiteralPath $path) $path
}

foreach ($command in $Commands) {
    $resolved = Get-Command $command -ErrorAction SilentlyContinue | Select-Object -First 1
    Add-Check 'Command' $command ([bool]$resolved) $(if ($resolved) { $resolved.Source } else { 'not found' })
}

$wsh = New-Object -ComObject WScript.Shell
$desktopRoots = @([Environment]::GetFolderPath('Desktop'), "$env:PUBLIC\Desktop") |
    Where-Object { $_ -and (Test-Path -LiteralPath $_) }
foreach ($root in $desktopRoots) {
    foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.lnk' -File -Force) {
        $link = $wsh.CreateShortcut($file.FullName)
        if ($link.TargetPath) {
            Add-Check 'Shortcut' $file.FullName (Test-Path -LiteralPath $link.TargetPath) $link.TargetPath
        }
    }
}

foreach ($scope in 'User','Machine') {
    $raw = [Environment]::GetEnvironmentVariable('Path', $scope)
    foreach ($entry in ($raw -split ';' | Where-Object { $_ })) {
        $expanded = [Environment]::ExpandEnvironmentVariables($entry.Trim())
        if ($expanded -match '^[A-Za-z]:\') {
            Add-Check "Path-$scope" $entry (Test-Path -LiteralPath $expanded) $expanded
        }
    }
}

if ($InventoryPath) {
    $inventoryExists = Test-Path -LiteralPath $InventoryPath
    Add-Check 'Inventory' $InventoryPath $inventoryExists 'Pre-change inventory exists'
    if ($inventoryExists) {
        $inventory = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json
        foreach ($disk in $inventory.VirtualDiskFiles) {
            $exists = Test-Path -LiteralPath $disk.FullName
            $sameLength = $exists -and ((Get-Item -LiteralPath $disk.FullName).Length -eq [int64]$disk.Length)
            Add-Check 'VirtualDisk' $disk.FullName $sameLength "Expected length: $($disk.Length)"
        }
    }
}

$checks
if ($checks.Where({ -not $_.Passed }).Count -gt 0) { exit 2 }

