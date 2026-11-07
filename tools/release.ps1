param(
    [ValidateSet('windows', 'linux', 'android', 'all')]
    [string]$Target = 'windows',

    [switch]$SkipBuild,
    [switch]$GenerateNotes,
    [switch]$AutoCommit,
    [switch]$AutoTag,
    [switch]$AutoPush,
    [switch]$PublishGithub,
    [string]$GithubToken = '',
    [string]$TagName = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Get-CurrentGitTag {
    $tag = & git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) {
        return $tag.Trim()
    }

    $tag = & git tag --list --sort=-version:refname 2>$null | Select-Object -First 1
    if ($tag) {
        return $tag.Trim()
    }

    return ''
}

function Get-PubspecVersion {
    $versionLine = Get-Content .\pubspec.yaml | Where-Object { $_ -match '^version:\s*' } | Select-Object -First 1
    if (-not $versionLine) {
        return 'unknown'
    }

    $match = [regex]::Match($versionLine, '^version:\s*(.+?)\s*$')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return 'unknown'
}

function Set-ArtifactName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseName,
        [Parameter(Mandatory = $true)]
        [string]$Version,
        [Parameter(Mandatory = $true)]
        [string]$Extension
    )

    return "$BaseName-$Version.$Extension"
}

function Publish-GithubRelease {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Tag,
        [Parameter(Mandatory = $true)]
        [string[]]$AssetPaths
    )

    if (-not $PublishGithub) {
        return
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Warning 'GitHub CLI (gh) not found. Skipping GitHub release upload.'
        return
    }

    $token = if ($GithubToken) { $GithubToken } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { '' }
    if (-not $token) {
        Write-Warning 'GH_TOKEN not set. Skipping GitHub release upload.'
        return
    }

    $env:GH_TOKEN = $token

    $releaseExists = & gh release view $Tag --json tagName 2>$null
    if ($LASTEXITCODE -ne 0) {
        & gh release create $Tag $AssetPaths --generate-notes --title $Tag
    }
    else {
        & gh release upload $Tag $AssetPaths --clobber
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to upload release assets for tag $Tag"
    }
}

Write-Host '==> Fetching latest tags from origin...'
$fetchTags = & git fetch --tags origin 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Failed to fetch tags from origin. Continuing with local tags if available.'
}

Write-Host '==> Syncing pubspec version from git tag...'
python .\tools\sync_version_from_git_tag.py

$version = Get-PubspecVersion
$tag = Get-CurrentGitTag
if (-not $tag) {
    $tag = "v$version"
}

if ($TagName) {
    $tag = $TagName.Trim()
}

if ($AutoCommit -or $AutoTag -or $AutoPush) {
    $gitUserName = & git config user.name 2>$null
    if (-not $gitUserName) {
        git config user.name 'release-bot'
    }

    $gitUserEmail = & git config user.email 2>$null
    if (-not $gitUserEmail) {
        git config user.email 'release-bot@local'
    }

    $pubspecChanged = & git diff --quiet -- pubspec.yaml
    if ($LASTEXITCODE -ne 0) {
        git add pubspec.yaml
        git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            git commit -m "chore: sync version to $version"
        }
    }
}

if ($AutoTag) {
    $tagToCreate = if ($TagName) { $TagName.Trim() } else { "v$version" }
    $existingTag = & git tag --list $tagToCreate
    if (-not $existingTag) {
        git tag -a $tagToCreate -m "Release $tagToCreate"
    }
    else {
        Write-Host "Tag $tagToCreate already exists. Reusing it."
    }
    $tag = $tagToCreate
}

if ($AutoPush) {
    git push origin HEAD
    if ($AutoTag) {
        git push origin --tags
    }
}

if ($SkipBuild) {
    Write-Host "==> Skipped build because -SkipBuild was specified. Current version: $version"
    exit 0
}

Write-Host "==> Building target: $Target"
$artifacts = @()
$artifactRoot = Join-Path $repoRoot 'release-artifacts'
if (Test-Path $artifactRoot) {
    Remove-Item $artifactRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $artifactRoot | Out-Null

if ($GenerateNotes -or $PublishGithub) {
    $notesPath = Join-Path $artifactRoot 'release-notes.md'
    python .\tools\generate_release_notes.py $tag $notesPath
    if (Test-Path $notesPath) {
        $artifacts += $notesPath
    }
}

switch ($Target) {
    'windows' {
        flutter pub get
        flutter build windows
        $buildDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
        if (Test-Path $buildDir) {
            $zipPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-windows' -Version $version -Extension 'zip')
            Compress-Archive -Path "$buildDir\*" -DestinationPath $zipPath -Force
            $artifacts += $zipPath
        }
    }
    'linux' {
        flutter pub get
        flutter build linux
        $buildDir = Join-Path $repoRoot 'build/linux/x64/release/bundle'
        if (Test-Path $buildDir) {
            $zipPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-linux' -Version $version -Extension 'zip')
            Compress-Archive -Path "$buildDir\*" -DestinationPath $zipPath -Force
            $artifacts += $zipPath
        }
    }
    'android' {
        flutter pub get
        flutter build apk
        $apkPath = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
        if (Test-Path $apkPath) {
            $copyPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-android' -Version $version -Extension 'apk')
            Copy-Item $apkPath $copyPath -Force
            $artifacts += $copyPath
        }
    }
    'all' {
        flutter pub get
        flutter build windows
        flutter build linux
        flutter build apk

        $windowsBuildDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
        if (Test-Path $windowsBuildDir) {
            $zipPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-windows' -Version $version -Extension 'zip')
            Compress-Archive -Path "$windowsBuildDir\*" -DestinationPath $zipPath -Force
            $artifacts += $zipPath
        }

        $linuxBuildDir = Join-Path $repoRoot 'build/linux/x64/release/bundle'
        if (Test-Path $linuxBuildDir) {
            $zipPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-linux' -Version $version -Extension 'zip')
            Compress-Archive -Path "$linuxBuildDir\*" -DestinationPath $zipPath -Force
            $artifacts += $zipPath
        }

        $apkPath = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
        if (Test-Path $apkPath) {
            $copyPath = Join-Path $artifactRoot (Set-ArtifactName -BaseName 'dcm-android' -Version $version -Extension 'apk')
            Copy-Item $apkPath $copyPath -Force
            $artifacts += $copyPath
        }
    }
}

if ($artifacts.Count -gt 0) {
    Write-Host "==> Built artifacts:"
    $artifacts | ForEach-Object { Write-Host "  - $_" }
}
else {
    Write-Warning 'No build artifacts were generated.'
}

if ($artifacts.Count -gt 0 -and $PublishGithub) {
    Publish-GithubRelease -Tag $tag -AssetPaths $artifacts
}

Write-Host '==> Release flow completed.'
