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
4. To change the playback content, log in to the CMS system first. In the Calendar feature, switch to the preset Playlist provided by the system.
5. Then open the Player feature and click Update Now to push the latest content to the player.
6. The player will receive the update and switch to the new content immediately.

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

## Contributing

Contributions are welcome. If you encounter a bug, want to report an issue, or propose a feature enhancement, please [create a new issue](https://github.com/s2001wincrown/dcm-flutter/issues/new).

Pull requests are also encouraged for code improvements, platform support, and new playback capabilities.

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=s2001wincrown/dcm-flutter&type=Date)](https://star-history.com/#s2001wincrown/dcm-flutter&Date)
