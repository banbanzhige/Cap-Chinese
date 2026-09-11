$ErrorActionPreference = 'Stop'
$capRoot = Split-Path $PSScriptRoot -Parent
$capProbe = Join-Path $capRoot 'tooling/cargo-probe'
$capTarget = Join-Path $capRoot 'upstream/Cap/target'
. (Join-Path $PSScriptRoot 'enter-dev.ps1')
$capBinDir = Join-Path $capProbe 'apps/desktop/src-tauri/binaries'
New-Item -ItemType Directory -Path $capBinDir -Force | Out-Null
foreach ($capBinary in @(
    @{Source='cap-muxer'; Destination='cap-muxer'},
    @{Source='cap'; Destination='cap-cli'},
    @{Source='cap'; Destination='cap-exporter'}
)) {
    $capSourceFile = Join-Path $capTarget ('debug/' + $capBinary.Source + '.exe')
    if (-not (Test-Path -LiteralPath $capSourceFile)) { throw "Missing built sidecar: $capSourceFile" }
    Copy-Item -LiteralPath $capSourceFile -Destination (Join-Path $capBinDir ($capBinary.Destination + '-x86_64-pc-windows-msvc.exe'))
}
Push-Location $capProbe
try {
    & cargo check --locked -p cap-desktop --target-dir $capTarget -j 2
    if ($LASTEXITCODE -ne 0) { throw "Native probe failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}
