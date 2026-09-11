param([switch]$RuntimeIsolation, [switch]$ChinesePreview, [switch]$ChinesePackage)

$ErrorActionPreference = 'Stop'
$capRoot = Split-Path $PSScriptRoot -Parent
$capProbe = Join-Path $capRoot 'tooling/cargo-probe'
$capCli = Join-Path $capRoot 'upstream/Cap/apps/desktop/node_modules/@tauri-apps/cli/tauri.js'
$capConfig = Join-Path $capRoot $(if ($ChinesePackage) { 'config/tauri.zh-package.json' } elseif ($ChinesePreview) { 'config/tauri.zh-preview.json' } elseif ($RuntimeIsolation) { 'config/tauri.runtime-test.json' } else { 'config/tauri.p0.json' })
$capFrontend = Join-Path $capRoot 'upstream/Cap/apps/desktop/.output/public/index.html'
if (-not (Test-Path -LiteralPath $capFrontend)) { throw 'Build the official desktop frontend first' }
if ($ChinesePackage) {
    & node (Join-Path $PSScriptRoot 'check-packaged-frontend.cjs')
    if ($LASTEXITCODE -ne 0) { throw 'Packaged frontend validation failed' }
}
$capMainSource = Get-Content -Raw -LiteralPath (Join-Path $capProbe 'apps/desktop/src-tauri/src/main.rs')
if (-not $ChinesePackage -and $capMainSource.Contains('.join("so.cap.desktop.zh")')) {
    throw 'The native source is now the Chinese package variant. Use -ChinesePackage to preserve earlier baseline EXEs.'
}
if (-not $RuntimeIsolation -and -not $ChinesePreview -and -not $ChinesePackage -and $capMainSource.Contains('.join("so.cap.desktop.p0")')) {
    throw 'The probe now contains runtime-isolation changes. Use -RuntimeIsolation to preserve the original baseline EXE.'
}
. (Join-Path $PSScriptRoot 'enter-dev.ps1')
$capPriorTargetDir = $env:CARGO_TARGET_DIR
$capPriorJobs = $env:CARGO_BUILD_JOBS
try {
    $env:CARGO_TARGET_DIR = Join-Path $capRoot 'upstream/Cap/target'
    $env:CARGO_BUILD_JOBS = '2'
    Push-Location (Join-Path $capProbe 'apps/desktop')
    try {
        & node $capCli build --debug --no-bundle --config $capConfig -- --locked
        if ($LASTEXITCODE -ne 0) { throw "Native build failed: $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    $env:CARGO_TARGET_DIR = $capPriorTargetDir
    $env:CARGO_BUILD_JOBS = $capPriorJobs
}
