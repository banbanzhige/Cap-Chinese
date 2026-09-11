param([switch]$Replace, [switch]$Prune)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-config.ps1')
$OutputName = $capReleaseName
$capRoot = Split-Path $PSScriptRoot -Parent
$capSource = Join-Path $capRoot 'upstream/Cap'
$capProbe = Join-Path $capRoot 'tooling/cargo-probe'
$capTarget = Join-Path $capSource 'target/debug'
$capPublishDist = Join-Path $capRoot 'dist'
$capDist = Join-Path $capRoot ('output/package-staging/' + [guid]::NewGuid().ToString('N'))
$capPublishedPaths = @($OutputName, "$OutputName.zip", "$OutputName-source.zip") | ForEach-Object { Join-Path $capPublishDist $_ }
foreach ($capPublishedPath in $capPublishedPaths) {
    if ((Test-Path -LiteralPath $capPublishedPath) -and -not $Replace) { throw "Release exists. Use -Replace to build and verify before replacing: $capPublishedPath" }
}
$capPackage = Join-Path $capDist $OutputName
$capZipPath = "$capPackage.zip"
$capSourceZip = Join-Path $capDist "$OutputName-source.zip"
$capCrt = 'C:/Program Files (x86)/Microsoft Visual Studio/2022/BuildTools/VC/Redist/MSVC/14.44.35112/x64/Microsoft.VC143.CRT'
foreach ($capPath in @($capPackage, $capZipPath, $capSourceZip)) {
    if (Test-Path -LiteralPath $capPath) { throw "Refusing to overwrite existing artifact: $capPath" }
}
$capInputs = @{
    'Cap Chinese.exe' = Join-Path $capTarget 'Cap Chinese.exe'
    'cap-muxer.exe' = Join-Path $capTarget 'cap-muxer.exe'
    'cap-cli.exe' = Join-Path $capRoot 'artifacts/zh-runtime/cap-zh-cli.exe'
    'cap-exporter.exe' = Join-Path $capRoot 'artifacts/zh-runtime/cap-zh-cli.exe'
}
foreach ($capInput in $capInputs.Values) { if (-not (Test-Path -LiteralPath $capInput)) { throw "Missing input: $capInput" } }
& node (Join-Path $PSScriptRoot 'check-packaged-frontend.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Frontend embedding regression check failed' }
& node (Join-Path $PSScriptRoot 'check-window-init.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Window initialization regression check failed' }
$capBaselines = @{
    'Cap - Development.exe' = 'FA4FB721F91DE6901D881635D1BC6DBA7E0409C7AD015BC03CA9353BD338B63F'
    'Cap - P0 Test.exe' = '781E983DA8DCB7AC853E4088D1B928ADBEBA9C3347D575D97D5E4326BB04258D'
    'Cap - Chinese Preview.exe' = '0B7FDEB9DCA6FC25A849B05A9D7959655629E1A6606A3EA01577D5198692F77F'
    'cap.exe' = '83F8675CC4D8667583001FBC80A37843D44DC6B2D0CCE3FAE4561581D568B08E'
}
foreach ($capEntry in $capBaselines.GetEnumerator()) {
    if ((Get-FileHash -LiteralPath (Join-Path $capTarget $capEntry.Key)).Hash -ne $capEntry.Value) { throw "Baseline changed: $($capEntry.Key)" }
}
New-Item -ItemType Directory -Path $capPackage | Out-Null
foreach ($capEntry in $capInputs.GetEnumerator()) { Copy-Item -LiteralPath $capEntry.Value -Destination (Join-Path $capPackage $capEntry.Key) }
$capDllNames = @('avcodec-61.dll','avdevice-61.dll','avfilter-10.dll','avformat-61.dll','avutil-59.dll','postproc-58.dll','swresample-5.dll','swscale-8.dll','onnxruntime.dll','onnxruntime_providers_shared.dll')
foreach ($capName in $capDllNames) { Copy-Item -LiteralPath (Join-Path $capTarget $capName) -Destination $capPackage }
Get-ChildItem -LiteralPath $capCrt -Filter '*.dll' -File | Copy-Item -Destination $capPackage
Copy-Item -LiteralPath (Join-Path $capTarget 'assets') -Destination $capPackage -Recurse
Copy-Item -LiteralPath (Join-Path $capRoot 'docs/PACKAGE-README.zh-CN.md') -Destination (Join-Path $capPackage '使用说明.md')
foreach ($capDocument in @('LICENSE','NOTICE')) {
    Copy-Item -LiteralPath (Join-Path $capRoot $capDocument) -Destination $capPackage
}
$capPackageDocs = Join-Path $capPackage 'docs'
New-Item -ItemType Directory -Path $capPackageDocs | Out-Null
foreach ($capDocument in @('LICENSING.md','OPEN-SOURCE.md','THIRD-PARTY-NOTICES.md','DEVELOPMENT.md')) {
    Copy-Item -LiteralPath (Join-Path $capRoot "docs/$capDocument") -Destination $capPackageDocs
}
$capLicenses = Join-Path $capPackage 'licenses'
Copy-Item -LiteralPath (Join-Path $capSource 'licenses') -Destination $capLicenses -Recurse
Get-ChildItem -LiteralPath (Join-Path $capRoot 'licenses') -File | Copy-Item -Destination $capLicenses
Copy-Item -LiteralPath (Join-Path $capSource 'LICENSE') -Destination (Join-Path $capLicenses 'Cap-LICENSE')
Copy-Item -LiteralPath (Join-Path $capRoot 'references/Cap-Chinese/LICENSE') -Destination (Join-Path $capLicenses 'Cap-Chinese-LICENSE')
foreach ($capDep in @('ffmpeg','onnxruntime')) { New-Item -ItemType Directory -Path (Join-Path $capLicenses $capDep) | Out-Null }
foreach ($capFile in @('LICENSE','README.txt')) { Copy-Item -LiteralPath (Join-Path $capSource "target/ffmpeg/$capFile") -Destination (Join-Path $capLicenses 'ffmpeg') }
foreach ($capFile in @('LICENSE','ThirdPartyNotices.txt','GIT_COMMIT_ID','VERSION_NUMBER')) { Copy-Item -LiteralPath (Join-Path $capSource "target/onnxruntime-win-x64-1.24.2/$capFile") -Destination (Join-Path $capLicenses 'onnxruntime') }

& git -c "safe.directory=$($capSource.Replace('\','/'))" -C $capSource archive --format=zip "--prefix=$capReleaseSourceName/" "--output=$capSourceZip" HEAD
if ($LASTEXITCODE -ne 0) { throw 'Source archive failed' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$capArchive = [IO.Compression.ZipFile]::Open($capSourceZip, [IO.Compression.ZipArchiveMode]::Update)
function Add-CapSourceFile([string]$File, [string]$Relative) {
    if ($Relative -match '(^|/)\.\.(/|$)|(^|/)\.env$') { throw "Unsafe archive entry: $Relative" }
    $capEntryName = "$capReleaseSourceName/" + $Relative.Replace('\','/')
    $capExisting = $capArchive.GetEntry($capEntryName)
    if ($capExisting) { $capExisting.Delete() }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($capArchive, $File, $capEntryName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
try {
    foreach ($capRepo in @($capSource,$capProbe)) {
        $capChanges = @(& git -c "safe.directory=$($capRepo.Replace('\','/'))" -c core.autocrlf=false -C $capRepo diff --name-only)
        if ($LASTEXITCODE -ne 0) { throw 'Could not enumerate changed source' }
        foreach ($capFile in $capChanges) {
            if ($capFile -match '\.d\.ts$') { continue }
            Add-CapSourceFile (Join-Path $capRepo $capFile) $capFile
        }
    }
    foreach ($capDir in @('translations','scripts')) {
        Get-ChildItem -LiteralPath (Join-Path $capRoot $capDir) -File | ForEach-Object {
            $capFolder = if ($capDir -eq 'scripts') { 'workspace-scripts' } else { $capDir }
            Add-CapSourceFile $_.FullName "zh-build/$capFolder/$($_.Name)"
        }
    }
    Add-CapSourceFile (Join-Path $capRoot 'docs/SOURCE-BUILD.zh-CN.md') '中文构建说明.md'
    Add-CapSourceFile (Join-Path $capRoot 'config/tauri.zh-source.json') 'zh-build/tauri.zh.json'
    Add-CapSourceFile (Join-Path $capRoot 'config/desktop.env.example') 'zh-build/desktop.env.example'
    Add-CapSourceFile (Join-Path $capRoot 'config/upstream.lock.json') 'zh-build/upstream.lock.json'
    foreach ($capDocument in @('LICENSE','NOTICE','README.md')) {
        Add-CapSourceFile (Join-Path $capRoot $capDocument) "zh-build/$capDocument"
    }
    foreach ($capDocument in @('LICENSING.md','OPEN-SOURCE.md','THIRD-PARTY-NOTICES.md','DEVELOPMENT.md')) {
        Add-CapSourceFile (Join-Path $capRoot "docs/$capDocument") "zh-build/docs/$capDocument"
    }
    Get-ChildItem -LiteralPath (Join-Path $capRoot 'licenses') -File | ForEach-Object {
        Add-CapSourceFile $_.FullName "zh-build/licenses/$($_.Name)"
    }
} finally { $capArchive.Dispose() }
Copy-Item -LiteralPath $capSourceZip -Destination (Join-Path $capPackage "$capReleaseSourceName.zip")
$capRelease | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $capPackage 'release.json') -Encoding UTF8

$capManifest = @(Get-ChildItem -LiteralPath $capPackage -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($capPackage.Length + 1).Replace('\','/'); bytes = $_.Length; sha256 = (Get-FileHash -LiteralPath $_.FullName).Hash }
})
$capManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $capPackage 'SHA256SUMS.json') -Encoding UTF8
[IO.Compression.ZipFile]::CreateFromDirectory($capPackage, $capZipPath, [IO.Compression.CompressionLevel]::Optimal, $true)
& (Join-Path $PSScriptRoot 'verify-chinese-package.ps1') -PackageDirectory $capPackage -NoResult
if (-not $?) { throw 'Staged package verification failed; published release is untouched' }
New-Item -ItemType Directory -Path $capPublishDist -Force | Out-Null
$capPrevious = Join-Path $capDist 'previous'
foreach ($capPublishedPath in $capPublishedPaths) {
    $capResolved = [IO.Path]::GetFullPath($capPublishedPath)
    if (-not $capResolved.StartsWith([IO.Path]::GetFullPath($capPublishDist) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Publish target outside dist' }
    if (Test-Path -LiteralPath $capPublishedPath) {
        $capExisting = Get-Item -LiteralPath $capPublishedPath -Force
        if ($capExisting.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to move a reparse point' }
        New-Item -ItemType Directory -Path $capPrevious -Force | Out-Null
        Move-Item -LiteralPath $capPublishedPath -Destination (Join-Path $capPrevious $capExisting.Name)
    }
}
foreach ($capArtifact in @($capPackage,$capZipPath,$capSourceZip)) { Move-Item -LiteralPath $capArtifact -Destination $capPublishDist }
$capPackage = Join-Path $capPublishDist $OutputName
$capZipPath = "$capPackage.zip"
$capSourceZip = Join-Path $capPublishDist "$OutputName-source.zip"
& (Join-Path $PSScriptRoot 'verify-chinese-package.ps1') -PackageDirectory $capPackage
if (-not $?) { throw "Published verification failed. Previous same-version release is at $capPrevious" }
$capResult = [ordered]@{
    version = $capRelease.version; locale = $capRelease.locale; revision = $capRelease.revision; platform = $capRelease.platform; build = $capRelease.build
    packageDirectory = $capPackage; packageZip = $capZipPath
    packageBytes = (Get-Item -LiteralPath $capZipPath).Length
    packageSha256 = (Get-FileHash -LiteralPath $capZipPath).Hash
    executableSha256 = (Get-FileHash -LiteralPath (Join-Path $capPackage 'Cap Chinese.exe')).Hash
    sourceZip = $capSourceZip; sourceSha256 = (Get-FileHash -LiteralPath $capSourceZip).Hash
    manifestFiles = $capManifest.Count; baselineHashesPreserved = $true
    runtimeUiVerified = $false; recordingTestsPerformed = $false; computerUsePerformed = $false
}
$capResult | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $capRoot 'config/zh-package-result.json') -Encoding UTF8
$capResult | ConvertTo-Json -Depth 5
if ($Prune) { & (Join-Path $PSScriptRoot 'clean-dist.ps1') -Apply }
