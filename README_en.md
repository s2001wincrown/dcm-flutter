# dcm-flutter

[中文](./README.md) | English

DMC Digital Signage Player

A cross-platform fullscreen digital signage and media playback solution built with Flutter and Dart. It is designed for multi-zone display scenarios where the screen can be divided into multiple independent playback areas, each with customizable size, layout, and content source.

## Product Overview

This project is a professional multi-screen playback system for digital signage, smart retail displays, information walls, and media presentation environments. It enables centralized or standalone playback of diverse content across multiple regions on one screen or across a group of connected displays.

### Core Features

- Fullscreen playback for large displays, wall-mounted screens, and digital signage installations.
- Flexible multi-region layout with configurable zone count, size, and position.
- Support for multiple content formats, including video, images, text, real-time information, PPT, PDF, HTML, scrolling text, and image slideshows.
- Program rotation and playlist scheduling across different zones.
- Playback from both local files and network-based media sources.
- Automatic startup on device boot.
- Standalone operation or synchronization with a CMS server for remote control, content updates, and centralized management.
- Cross-platform deployment on Windows, macOS, Linux, Android, iOS, and Web.

### Key Highlights

- Multi-zone, multi-content playback for digital signage and information display.
- Flexible scheduling and central management through CMS synchronization.
- Unified cross-platform delivery built on Flutter and Dart.

### Typical Use Cases

- Corporate lobby and reception displays
- Retail storefronts and smart shopping environments
- Public information walls and transit terminals
- Educational or conference presentation screens
- Remote signage management with scheduled content updates

### Platform and Technology

The application is implemented with Flutter and Dart, providing a unified codebase for cross-platform deployment while supporting both independent local playback and synchronization with the CMS demo system at http://121.40.137.228:8080/demo.

[![build](https://img.shields.io/github/actions/workflow/status/s2001wincrown/dcm-flutter/build.yml?style=for-the-badge)](https://github.com/s2001wincrown/dcm-flutter/actions)
[![release](https://img.shields.io/badge/beta-2025.4-gold?style=for-the-badge)](https://github.com/s2001wincrown/dcm-flutter/releases) ![downloads](https://img.shields.io/github/downloads/s2001wincrown/dcm-flutter/total?style=for-the-badge&color=blue) [![project](https://img.shields.io/badge/project-grey?style=for-the-badge)](https://github.com/orgs/s2001wincrown/projects/3)

![](https://m3-markdown-badges.vercel.app/stars/7/2/s2001wincrown/dcm-flutter)
![](https://m3-markdown-badges.vercel.app/issues/1/2/s2001wincrown/dcm-flutter)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Windows/windows3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Linux/linux3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/macOS/macos3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Android/android3.svg)

Supported platforms: Windows, macOS, Linux, Android, iOS, and Web.

## Supported Platform Versions

- Flutter SDK: current range `>=3.1.3 <4.0.0` in `pubspec.yaml`; recommended Flutter 3.29.0 or later.
- Android: current values use `minSdkVersion flutter.minSdkVersion` and `targetSdkVersion flutter.targetSdkVersion` in `android/app/build.gradle`; recommended to use Android SDK settings compatible with the active Flutter SDK.
- macOS: current minimum macOS 10.14.6 in `macos/Podfile`; recommended macOS 10.14.6 or later.
- Windows: current support for Flutter Windows desktop; recommended to build and run on Windows 10/11.
- Linux: current support for Flutter Linux desktop; recommended to install GTK 3 and `libmpv` runtime dependencies.
- Web: current support for Flutter Web deployment; recommended to use a modern browser.

### Detailed Platform Support

| Platform | Current | Recommended |
| --- | --- | --- |
| Android | Uses Flutter-managed values in `android/app/build.gradle`: `minSdkVersion flutter.minSdkVersion` / `targetSdkVersion flutter.targetSdkVersion` | Android 5.0+ (API 21+) |
| iOS | Managed by the Flutter SDK; exact values depend on the iOS project configuration | iOS 9+ (prefer newer versions) |
| macOS | Minimum macOS 10.14.6 via `macos/Podfile` | macOS 10.14.6+ |
| Windows | Supports Flutter Windows desktop builds | Windows 10/11 |
| Linux | Supports Flutter Linux desktop builds | Modern GNU/Linux distro with GTK 3 and `libmpv` |
| Web | Supports Flutter Web deployment | Modern web browser |

## Product Screenshots

<table>
  <tr>
    <td>
      <img src='./screenshots/screenshot1.png' alt="horizontal-a2-1">
    </td>
    <td>
      <img src='./screenshots/screenshot2.png' alt="horizontal-a2-2">
    </td>
  </tr>
  <tr>
    <td>
      <img src='./screenshots/screenshot3.png' alt="horizontal-a3">
    </td>
    <td>
      <img src='./screenshots/screenshot4.png' alt="vertical-b4">
    </td>
  </tr>
</table>

## App Startup and CMS Content Synchronization

1. Download the installer or application package for your platform from the GitHub Releases page: <https://github.com/s2001wincrown/dcm-flutter/releases>.
2. Install and launch the application. On first startup, the screen may appear black for a short time while the app automatically synchronizes content from the demo CMS system at http://121.40.137.228:8080/demo.
3. Once the synchronization is complete, the app will automatically enter playback mode and start showing the current scheduled content.
4. To change the playback content, log in to the demo CMS system first. Use username: `DEMOUser` and password: `DEMOUser`.
5. In the Calendar feature, switch to the preset Playlist provided by the system.
6. Open the Player feature, go to the Player list (`./screenshots/cms2.png`), select the Player to update, and click `Update Now` to push the latest content to the player.
7. The player will receive the update and switch to the new content immediately.

<table>
  <tr>
    <td>
      <img src='./screenshots/cms1.png' alt="cms-calendar">
    </td>
    <td>
      <img src='./screenshots/cms2.png' alt="cms-player">
    </td>
  </tr>
</table>

## For Developers

To build and run this project locally, first set up the Flutter environment according to the [official guide](https://docs.flutter.dev/get-started/install/). Please use Flutter version **3.29.0** or higher.

Once the environment is ready, install the required dependencies with:

- `flutter pub get`
- `dart run whisper4dart:setup --prebuilt`

### Windows

Before building for Windows, prepare the `libmpv` runtime dependency with:

- `dart run libmpv_dart:setup --platform windows`

Then generate the executable with:

- `flutter build windows`

### Linux

After setting up Flutter, install `libmpv-dev` through your system package manager or another supported method.

Generate the Linux build with:

- `flutter build linux`

### macOS

Generate the macOS build with:

- `flutter build macos`

### Android

> Please run on tablet devices.

Generate the APK installation file with:

- `flutter build apk`

## Release Notes

This project supports syncing the version in `pubspec.yaml` from git tags and provides a one-click script for building and publishing releases.

### Version Sync

From the project root, run:

```bash
git fetch --tags origin
python tools/sync_version_from_git_tag.py
```

The script resolves the latest tag in this order:

1. `git describe --tags --abbrev=0`
2. local newest tag
3. remote newest tag
4. if no tag exists, keep the current version unchanged

It also strips the leading `v`, for example:

- `v1.0.1` -> `1.0.1`

### Local Release Script

Run from Windows PowerShell:

```powershell
./tools/release.ps1 -Target windows
```

Optional arguments:

```powershell
./tools/release.ps1 -Target all
./tools/release.ps1 -Target linux -SkipBuild
./tools/release.ps1 -Target windows -GenerateNotes
./tools/release.ps1 -Target windows -AutoCommit -AutoTag
./tools/release.ps1 -Target windows -AutoCommit -AutoTag -AutoPush
./tools/release.ps1 -Target windows -AutoCommit -AutoTag -AutoPush -PublishGithub -GithubToken YOUR_GH_TOKEN
```

The script automatically performs:

- fetch remote tags
- sync the version to `pubspec.yaml`
- optionally commit the `pubspec.yaml` change
- optionally create and push the git tag
- generate release notes
- build the selected platform artifacts
- optionally upload to GitHub Release

### Full Release Workflow

If you want the complete flow of “sync version + commit + tag + push + release”, run:

```powershell
./tools/release.ps1 -Target windows -AutoCommit -AutoTag -AutoPush -PublishGithub -GithubToken YOUR_GH_TOKEN
```

It will:

1. fetch the newest remote tag
2. sync the version into `pubspec.yaml`
3. `git add pubspec.yaml`
4. `git commit -m "chore: sync version to X.Y.Z"`
5. create a tag such as `v1.0.1`
6. `git push origin HEAD`
7. `git push origin --tags`
8. build the package and upload to GitHub Release

### Upload to GitHub Release

If GitHub CLI is installed and `GH_TOKEN` is configured, run:

```powershell
$env:GH_TOKEN = 'YOUR_GITHUB_TOKEN'
./tools/release.ps1 -Target windows -PublishGithub
```

Or pass the token directly:

```powershell
./tools/release.ps1 -Target windows -PublishGithub -GithubToken YOUR_GITHUB_TOKEN
```

> If the network is unavailable or remote tag fetch fails, the script keeps the local tag and continues the release flow instead of aborting.

## Contributing

Contributions are welcome. If you encounter a bug, want to report an issue, or propose a feature enhancement, please [create a new issue](https://github.com/s2001wincrown/dcm-flutter/issues/new).

Pull requests are also encouraged for code improvements, platform support, and new playback capabilities.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=s2001wincrown/dcm-flutter&type=Date)](https://star-history.com/#s2001wincrown/dcm-flutter&Date)
