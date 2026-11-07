<#
Run this script from the repository root to produce Windows installers/packages.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File windows\package_windows.ps1

It will build the CMake `package` target in `build/windows/x64` which runs CPack.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$buildDir = Join-Path $repoRoot "build\windows\x64"

Write-Host "Repository root: $repoRoot"
Write-Host "Build directory: $buildDir"

if (-Not (Test-Path $buildDir)) {
    Write-Error "Build directory not found. Run 'flutter build windows' first."
    exit 1
}

# Try to find cmake in PATH, otherwise fallback to Visual Studio shipped cmake
$cmakeCmd = Get-Command cmake -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source -ErrorAction SilentlyContinue
if (-not $cmakeCmd) {
    $vsCMake = 'C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
    if (Test-Path $vsCMake) { $cmakeCmd = $vsCMake }
}

if (-not $cmakeCmd) {
    Write-Error "cmake not found in PATH and Visual Studio cmake not found. Please install CMake or add it to PATH."
    exit 2
}

Write-Host "Using cmake: $cmakeCmd"

try {
    & $cmakeCmd --build $buildDir --target package --config Release
    Write-Host "Packaging finished. Check $buildDir for packages." -ForegroundColor Green
} catch {
    Write-Error "Packaging failed: $_"
    exit 3
}
