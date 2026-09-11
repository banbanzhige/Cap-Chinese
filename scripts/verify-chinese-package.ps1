param([string]$PackageDirectory, [switch]$NoResult)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-config.ps1')
$PackageName = $capReleaseName
$capRoot = Split-Path $PSScriptRoot -Parent
$capPackage = if ($PackageDirectory) { [IO.Path]::GetFullPath($PackageDirectory) } else { Join-Path $capRoot "dist/$PackageName" }
if ((Split-Path $capPackage -Leaf) -ne $PackageName) { throw 'Package directory must match release.json' }
$capManifest = Get-Content -Raw -LiteralPath (Join-Path $capPackage 'SHA256SUMS.json') | ConvertFrom-Json
foreach ($capFile in $capManifest) {
    $capPath = [IO.Path]::GetFullPath((Join-Path $capPackage $capFile.path))
    if (-not $capPath.StartsWith($capPackage + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path outside package' }
    if ((Get-Item -LiteralPath $capPath).Length -ne $capFile.bytes -or (Get-FileHash -LiteralPath $capPath).Hash -ne $capFile.sha256) { throw "Manifest mismatch: $($capFile.path)" }
}
. (Join-Path $PSScriptRoot 'enter-dev.ps1')
$capDependencies = @()
foreach ($capBinary in @(Get-ChildItem -LiteralPath $capPackage -File | Where-Object { $_.Extension -in @('.exe','.dll') })) {
    $capOutput = & dumpbin /dependents $capBinary.FullName
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect $($capBinary.Name)" }
    foreach ($capLine in $capOutput) {
        if ($capLine -match '^\s+([a-zA-Z0-9_.-]+\.dll)\s*$') {
            $capDll = $Matches[1]
            $capLocation = if (Test-Path -LiteralPath (Join-Path $capPackage $capDll)) { 'package' }
                elseif ($capDll -match '^(api-ms-win-|ext-ms-win-)') { 'Windows API set' }
                elseif (Test-Path -LiteralPath (Join-Path ([Environment]::SystemDirectory) $capDll)) { 'Windows system' }
                else { throw "Missing dependency: $($capBinary.Name) -> $capDll" }
            $capDependencies += [ordered]@{ binary=$capBinary.Name; dependency=$capDll; location=$capLocation }
        }
    }
}
$capExe = Join-Path $capPackage 'Cap Chinese.exe'
$capHeaders = (& dumpbin /headers $capExe) -join "`n"
if ($capHeaders -notmatch '8664 machine \(x64\)' -or $capHeaders -notmatch '2 subsystem \(Windows GUI\)') { throw 'Unexpected executable architecture/subsystem' }
if ((Get-Item -LiteralPath $capExe).VersionInfo.ProductVersion -ne $capRelease.version) { throw 'Unexpected version' }
$capIdentity = Get-Content -Raw -LiteralPath (Join-Path $capPackage 'release.json') | ConvertFrom-Json
if ($capIdentity.version -ne $capRelease.version -or $capIdentity.locale -ne $capRelease.locale -or $capIdentity.revision -ne $capRelease.revision) { throw 'Package release identity mismatch' }
foreach ($capAsset in @('backgrounds','music','rive')) {
    if (@(Get-ChildItem -LiteralPath (Join-Path $capPackage "assets/$capAsset") -Recurse -File).Count -eq 0) { throw "Empty asset group: $capAsset" }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$capArchive = [IO.Compression.ZipFile]::OpenRead("$capPackage.zip")
try {
    foreach ($capFile in $capManifest) {
        $capEntry = $capArchive.GetEntry("$PackageName/$($capFile.path)")
        if (-not $capEntry -or $capEntry.Length -ne $capFile.bytes) { throw "ZIP entry missing or wrong length: $($capFile.path)" }
        $capStream = $capEntry.Open()
        $capHasher = [Security.Cryptography.SHA256]::Create()
        try { $capHash = [BitConverter]::ToString($capHasher.ComputeHash($capStream)).Replace('-','') }
        finally { $capStream.Dispose(); $capHasher.Dispose() }
        if ($capHash -ne $capFile.sha256) { throw "ZIP content mismatch: $($capFile.path)" }
    }
} finally { $capArchive.Dispose() }
$capSourceArchive = [IO.Compression.ZipFile]::OpenRead((Join-Path $capPackage "$capReleaseSourceName.zip"))
try {
    $capUnsafe = @($capSourceArchive.Entries | Where-Object { $_.FullName -match '(^|/)(node_modules|target|\.git|\.env)(/|$)' })
    if ($capUnsafe.Count) { throw 'Unexpected private/cache content in source archive' }
    foreach ($capSource in @('apps/desktop/src/routes/editor/ConfigSidebar.tsx','apps/desktop/src-tauri/src/main.rs','apps/cli/src/credentials.rs','Cargo.lock','zh-build/tauri.zh.json','中文构建说明.md')) {
        if (-not $capSourceArchive.GetEntry("$capReleaseSourceName/$capSource")) { throw "Missing source: $capSource" }
    }
    $capSourceEntries = $capSourceArchive.Entries.Count
} finally { $capSourceArchive.Dispose() }
$capResult = [ordered]@{
    package=$capPackage; manifestFiles=$capManifest.Count; archivePayloadHashesVerified=$true
    sourceEntries=$capSourceEntries; nativeDependencies=$capDependencies
    version=$capRelease.version; revision=$capRelease.revision; architecture='x64'; subsystem='Windows GUI'
    packageSha256=(Get-FileHash -LiteralPath "$capPackage.zip").Hash
    uiRuntimeVerified=$false; recordingTestPerformed=$false
}
if (-not $NoResult) { $capResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $capRoot 'config/zh-package-verification.json') -Encoding UTF8 }
"PASS: $($capManifest.Count) packaged files and ZIP payload hashes; $($capDependencies.Count) PE imports resolved; $capSourceEntries source entries. No UI or recording test performed."
