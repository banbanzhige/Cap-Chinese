param([switch]$Apply)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-config.ps1')
$capRoot = Split-Path $PSScriptRoot -Parent
$capDist = [IO.Path]::GetFullPath((Join-Path $capRoot 'dist'))
if (-not (Test-Path -LiteralPath $capDist)) { throw 'dist does not exist' }
if ((Get-Item -LiteralPath $capDist -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'dist must not be a reparse point' }
$capKeep = @($capReleaseName, "$capReleaseName.zip", "$capReleaseSourceName.zip")
foreach ($capName in $capKeep) { if (-not (Test-Path -LiteralPath (Join-Path $capDist $capName))) { throw "Current release is incomplete: $capName" } }
$capOld = @(Get-ChildItem -LiteralPath $capDist -Force | Where-Object { $_.Name -notin $capKeep })
foreach ($capItem in $capOld) {
    if ($capItem.Name -notmatch '^(?:Cap-Chinese-\d+\.\d+\.\d+-windows-x64(?:-r\d+)?|\d+\.\d+\.\d+-zh-CN)(?:-source)?(?:\.zip)?$') { throw "Unknown dist item; review manually: $($capItem.FullName)" }
    $capAbsolute = [IO.Path]::GetFullPath($capItem.FullName)
    if (-not $capAbsolute.StartsWith($capDist + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Cleanup target outside dist' }
    $capTree = @($capItem)
    if ($capItem.PSIsContainer) { $capTree += @(Get-ChildItem -LiteralPath $capAbsolute -Recurse -Force) }
    if (@($capTree | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw "Reparse point in cleanup target: $capAbsolute" }
    [pscustomobject]@{ Action = $(if ($Apply) { 'Delete after current verification' } else { 'Preview only' }); Path=$capAbsolute; Bytes=($capTree | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum }
}
if (-not $Apply) { return }
& (Join-Path $PSScriptRoot 'verify-chinese-package.ps1')
if (-not $?) { throw 'Current release verification failed; no old files deleted' }
foreach ($capItem in $capOld) {
    Remove-Item -LiteralPath $capItem.FullName -Recurse -Force
}
"Removed $($capOld.Count) old dist entries. Only $capReleaseName remains; source and English baselines outside dist were not touched."
