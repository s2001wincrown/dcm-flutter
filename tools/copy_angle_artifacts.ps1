Param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

# Destination ANGLE folder inside build output
$dest = Join-Path $RepoRoot "build\windows\x64\ANGLE"
if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

$files = @('vk_swiftshader.dll','vulkan-1.dll','zlib.dll')

# Candidate source directories to search for ANGLE artifacts
$candidates = @(
    "$env:USERPROFILE\AppData\Local\Android\Sdk\emulator\lib64\gles_angle",
    "$env:ANDROID_HOME\emulator\lib64\gles_angle",
    "D:\\Android\\android-sdk\\emulator\\lib64\\gles_angle",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\emulator\lib64\vulkan",
    "$env:ANDROID_HOME\emulator\lib64\vulkan",
    "D:\\Android\\android-sdk\\emulator\\lib64\\vulkan",
    "$RepoRoot\build\windows\x64\ANGLE",
    "$RepoRoot\..\build\windows\x64\ANGLE",
    "$RepoRoot\windows\flutter\ephemeral",
    "$env:FLUTTER_ROOT\bin\cache\artifacts\engine\windows-x64"
)

$copied = @()
$missing = @()

Write-Host "Destination: $dest"

foreach ($file in $files) {
    $found = $false
    foreach ($dir in $candidates) {
        if (-not $dir) { continue }
        $src = Join-Path $dir $file
        if (Test-Path $src) {
            try {
                Copy-Item -Path $src -Destination $dest -Force
                Write-Host "Copied $file from $dir"
                $copied += $file
                $found = $true
                break
            } catch {
                Write-Warning "Failed to copy $src : $_"
            }
        }
    }
    if (-not $found) { $missing += $file }
}

if ($copied.Count -gt 0) { Write-Host "Copied files: $($copied -join ', ')" }
if ($missing.Count -gt 0) {
    Write-Warning "Missing files not found in candidate locations: $($missing -join ', ')"
    exit 1
} else {
    Write-Host "All required ANGLE artifacts are present in $dest"
    exit 0
}
