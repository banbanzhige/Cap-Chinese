$ErrorActionPreference = 'Stop'
$capRoot = Split-Path $PSScriptRoot -Parent
$capPnpm = Join-Path $capRoot 'tooling/node_modules/pnpm/bin/pnpm.cjs'
if (-not (Test-Path -LiteralPath $capPnpm)) {
    throw 'Project pnpm missing. Run: npm.cmd ci --prefix tooling --cache tooling/.npm-cache --ignore-scripts --no-audit --no-fund'
}
$capPreviousPath = $env:PATH
try {
    $env:PATH = (Join-Path $capRoot 'tooling/node_modules/.bin') + ';' + $env:PATH
    Push-Location (Join-Path $capRoot 'upstream/Cap')
    try {
        & node $capPnpm @args
        if ($LASTEXITCODE -ne 0) { throw "pnpm failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    $env:PATH = $capPreviousPath
}
