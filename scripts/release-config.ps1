$capReleaseRoot = Split-Path $PSScriptRoot -Parent
$capRelease = Get-Content -Raw -LiteralPath (Join-Path $capReleaseRoot 'config/release.json') | ConvertFrom-Json
if ($capRelease.version -notmatch '^\d+\.\d+\.\d+$' -or $capRelease.locale -ne 'zh-CN' -or $capRelease.platform -ne 'windows-x64') { throw 'Invalid release identity' }
if ($capRelease.revision -isnot [long] -and $capRelease.revision -isnot [int]) { throw 'Revision must be an integer' }
if ($capRelease.revision -lt 1) { throw 'Revision must be positive' }
$capReleaseName = "$($capRelease.version)-$($capRelease.locale)"
$capReleaseSourceName = "$capReleaseName-source"
