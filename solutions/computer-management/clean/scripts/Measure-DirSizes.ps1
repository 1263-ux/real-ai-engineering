<#
.SYNOPSIS
  Read-only directory size ranking to answer "what is eating space".
  robocopy /L + /XJ, immune to junction double-counting.

.DESCRIPTION
  - Measures each subdirectory's byte total with robocopy /L (list mode, no copy)
    + /XJ (exclude junctions). Faster than Get-ChildItem -Recurse and does not
    double-count junction aliases (Application Data -> AppData\Roaming, etc.).
  - Unmeasurable directories (access denied / protected) return -1 and are shown
    as "unmeasured", never as 0.
  - Bottom summary compares measured total vs drive used; the difference is
    labeled "unaccounted" and never attributed without evidence.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Path = 'C:\',
    [int]$Top = 0
)
$ErrorActionPreference = 'SilentlyContinue'

$root = [System.IO.Path]::GetFullPath($Path)
$driveRoot = [System.IO.Path]::GetPathRoot($root)

function Measure-DirBytes([string]$Dir) {
    $out = robocopy $Dir "$env:TEMP\__dirsize_null__" /L /S /XJ /NJH /BYTES /NFL /NDL /R:0 /W:0 2>&1 | Out-String
    if ($out -match 'Bytes\s*:\s*([\d,]+)') { return [long]($Matches[1] -replace ',', '') }
    return -1
}

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($driveRoot.TrimEnd('\'))'"
$dirs = Get-ChildItem $root -Directory -Force | ForEach-Object {
    [pscustomobject]@{ Bytes = Measure-DirBytes $_.FullName; Name = $_.Name }
}
$rootFiles = (Get-ChildItem $root -File -Force | Measure-Object Length -Sum).Sum

"=== $root directory size ranking (junctions excluded) ==="
$topN = if ($Top -gt 0) { $Top } else { $dirs.Count }
$dirs | Sort-Object Bytes -Descending | Select-Object -First $topN | ForEach-Object {
    if ($_.Bytes -ge 0) { "{0,9:N2} GB  {1}" -f ($_.Bytes / 1GB), $_.Name }
    else { "{0,9} GB  {1}  [unmeasured]" -f '?', $_.Name }
}

$measured = ($dirs | Where-Object { $_.Bytes -ge 0 } | Measure-Object Bytes -Sum).Sum
$usedBytes = $disk.Size - $disk.FreeSpace
$unaccounted = $usedBytes - $measured - $rootFiles
""
"measured dirs : {0,9:N2} GB" -f ($measured / 1GB)
"root files    : {0,9:N2} GB  (pagefile/hiberfil etc.)" -f ($rootFiles / 1GB)
"drive used    : {0,9:N2} GB" -f ($usedBytes / 1GB)
"unaccounted   : {0,9:N2} GB  (protected dirs / system files / NTFS metadata - verify before attributing)" -f ($unaccounted / 1GB)
