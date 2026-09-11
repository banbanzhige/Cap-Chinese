$ErrorActionPreference = 'Stop'
$capWorkspace = Split-Path $PSScriptRoot -Parent
$capVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path -LiteralPath $capVswhere)) { throw 'Visual Studio Installer not found' }
$capVsPath = & $capVswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $capVsPath) { throw 'Visual Studio C++ tools not found' }
$capDevShell = Join-Path $capVsPath 'Common7/Tools/Launch-VsDevShell.ps1'
& $capDevShell -Arch amd64 -HostArch amd64 -SkipAutomaticLocation
if (-not $?) { throw 'Could not initialize Visual Studio developer shell' }
$capPathEntries = @(
    (Join-Path $capWorkspace 'tooling/node_modules/.bin'),
    (Join-Path $capVsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin'),
    (Join-Path $capVsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja'),
    (Join-Path $capVsPath 'VC/Tools/LLVM/x64/bin'),
    (Join-Path $capVsPath 'VC/vcpkg')
)
$env:PATH = ($capPathEntries -join ';') + ';' + $env:PATH
$env:VCPKG_ROOT = Join-Path $capVsPath 'VC/vcpkg'
Write-Host 'Cap x64 build shell initialized for this process only. No server started.'
