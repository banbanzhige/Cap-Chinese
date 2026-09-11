param([switch]$RequireBuildReady)

$ErrorActionPreference = 'Stop'
$capRoot = Split-Path $PSScriptRoot -Parent
$capLock = Get-Content -Raw -LiteralPath (Join-Path $capRoot 'config/upstream.lock.json') | ConvertFrom-Json
$capSource = Join-Path $capRoot $capLock.sourceDirectory
$capRows = [System.Collections.Generic.List[object]]::new()
function Add-CapCheck($Name, [bool]$Passed, $Detail) {
    $capRows.Add([pscustomobject]@{ Check = $Name; Status = $(if ($Passed) { 'OK' } else { 'PENDING' }); Detail = $Detail })
}

$capNode = Get-Command node -ErrorAction SilentlyContinue
if ($capNode) {
    $capNodeVersion = & node --version
    Add-CapCheck 'Node >=20' ([int]($capNodeVersion.TrimStart('v').Split('.')[0]) -ge $capLock.nodeMinimumMajor) $capNodeVersion
} else { Add-CapCheck 'Node >=20' $false 'Not found' }

$capGit = Get-Command git -ErrorAction SilentlyContinue
if ($capGit -and (Test-Path -LiteralPath (Join-Path $capSource '.git'))) {
    $capCommit = & git -c "safe.directory=$($capSource.Replace('\','/'))" -C $capSource rev-parse HEAD
    Add-CapCheck 'Official source commit' ($LASTEXITCODE -eq 0 -and $capCommit -eq $capLock.commit) $capCommit
} else { Add-CapCheck 'Official source commit' $false 'Git or source checkout missing' }
foreach ($capEntry in $capLock.lockfiles.PSObject.Properties) {
    $capFile = Join-Path $capSource $capEntry.Name
    $capHash = if (Test-Path -LiteralPath $capFile) { (Get-FileHash -LiteralPath $capFile -Algorithm SHA256).Hash } else { 'Missing' }
    Add-CapCheck $capEntry.Name ($capHash -eq $capEntry.Value) $capHash
}

$capPnpm = Join-Path $capRoot 'tooling/node_modules/pnpm/bin/pnpm.cjs'
if ($capNode -and (Test-Path -LiteralPath $capPnpm)) {
    $capPnpmVersion = & node $capPnpm --version
    Add-CapCheck 'Project pnpm' ($LASTEXITCODE -eq 0 -and $capPnpmVersion -eq $capLock.pnpm) $capPnpmVersion
} else { Add-CapCheck 'Project pnpm' $false 'Local pnpm 10.5.2 not installed' }

if (Get-Command rustup -ErrorAction SilentlyContinue) {
    $capToolchains = @(& rustup toolchain list)
    Add-CapCheck 'Rust 1.88.0' ([bool]($capToolchains -match '^1\.88\.0-x86_64-pc-windows-msvc')) ($capToolchains -join '; ')
} else { Add-CapCheck 'Rust 1.88.0' $false 'rustup not found' }

$capVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$capVs = $null
if (Test-Path -LiteralPath $capVswhere) {
    $capVsJson = & $capVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -format json
    $capVs = @($capVsJson | ConvertFrom-Json) | Select-Object -First 1
}
Add-CapCheck 'VS C++ >=17.12' ($null -ne $capVs -and [version]$capVs.installationVersion -ge [version]'17.12') $(if ($capVs) { $capVs.installationVersion } else { 'Not found' })
foreach ($capPart in @(
    @{Name='LLVM libclang'; Path='VC/Tools/LLVM/x64/bin/libclang.dll'},
    @{Name='CMake'; Path='Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'},
    @{Name='Ninja'; Path='Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe'},
    @{Name='Vcpkg'; Path='VC/vcpkg/vcpkg.exe'}
)) {
    $capPartPath = if ($capVs) { Join-Path $capVs.installationPath $capPart.Path } else { '' }
    Add-CapCheck $capPart.Name ([bool]$capPartPath -and (Test-Path -LiteralPath $capPartPath)) $capPartPath
}

$capWebview = Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\*','HKCU:\Software\Microsoft\EdgeUpdate\Clients\*' -ErrorAction SilentlyContinue | Where-Object { $_.name -eq 'Microsoft Edge WebView2 Runtime' } | Select-Object -First 1
Add-CapCheck 'WebView2' ([bool]$capWebview) $(if ($capWebview) { $capWebview.pv } else { 'Not detected' })
$capDrive = (Get-Item -LiteralPath $capRoot).PSDrive
$capFreeGB = [math]::Round($capDrive.Free / 1GB, 1)
Add-CapCheck 'Build disk headroom' ($capFreeGB -ge 50) "$($capDrive.Name): $capFreeGB GiB free; local safety budget is 50 GiB, not an upstream minimum"
foreach ($capArtifact in @(
    @{Name='JS dependencies'; Path='node_modules/.modules.yaml'},
    @{Name='Desktop environment'; Path='.env'},
    @{Name='FFmpeg headers'; Path='target/native-deps/include/libavcodec/avcodec.h'},
    @{Name='ONNX Runtime'; Path='target/native-deps/onnxruntime/lib/onnxruntime.dll'},
    @{Name='Cargo native config'; Path='.cargo/config.toml'}
)) {
    $capArtifactPath = Join-Path $capSource $capArtifact.Path
    Add-CapCheck $capArtifact.Name (Test-Path -LiteralPath $capArtifactPath) $capArtifact.Path
}
$capRows | Format-Table -AutoSize -Wrap
$capPending = @($capRows | Where-Object Status -eq 'PENDING').Count
Write-Host "$capPending pending checks. File presence does not prove a successful build."
if ($RequireBuildReady -and $capPending -gt 0) { exit 1 }
