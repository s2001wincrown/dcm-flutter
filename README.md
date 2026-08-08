# dcm-flutter

中文 | [English](./README_en.md)

DMC Digital Signage Player

基于 Flutter 和 Dart 构建的跨平台全屏数字标牌与媒体播放解决方案，适用于多区域显示布局场景。系统可将屏幕划分为多个可自定义大小和位置的播放区域，并支持在本地文件与网络资源之间切换播放各类媒体内容。

## 产品概览

本项目是一款面向数字标牌、智能零售展示、信息墙与媒体展示场景的专业多屏播放系统。它支持在单屏或多屏环境下，按区域组合播放多种内容，并实现统一管理与灵活轮播。

### 核心功能

- 支持在全屏模式下播放大屏、墙面显示器或数字标牌内容。
- 支持灵活的多区域布局，可自定义分区数量、区域尺寸与位置。
- 支持播放多种内容类型，包括视频、图片、文本、实时信息、PPT、PDF、HTML、滚动文本以及图片幻灯片。
- 支持多个节目或播放列表在不同区域之间轮播与排程。
- 支持播放本地媒体文件，也支持在线/网络内容。
- 支持系统开机自动启动。
- 可作为单机播放器独立运行，也可与 CMS 服务同步更新，实现远程内容管理与集中控制。
- 支持 Windows、macOS、Linux、Android、iOS 和 Web 等多平台部署。

### 亮点摘要

- 面向数字标牌与信息展示的多区域、多内容播放能力。
- 支持节目轮播与 CMS 同步管理，便于集中更新。
- 基于 Flutter 与 Dart 提供统一的跨平台交付能力。

### 典型应用场景

- 企业前台与接待展示屏
- 零售门店与智能购物场景
- 公共信息墙与交通枢纽终端
- 教育培训与会议演示屏幕
- 通过排程更新内容的远程数字标牌管理

### 平台与技术

本应用采用 Flutter 与 Dart 实现，提供统一的跨平台代码能力，同时支持独立本地播放与 CMS 演示系统 http://121.40.137.228:8080/demo 的同步更新。

[![build](https://img.shields.io/github/actions/workflow/status/s2001wincrown/dcm-flutter/build.yml?style=for-the-badge)](https://github.com/s2001wincrown/dcm-flutter/actions)
[![release](https://img.shields.io/badge/beta-2025.4-gold?style=for-the-badge)](https://github.com/s2001wincrown/dcm-flutter/releases) ![downloads](https://img.shields.io/github/downloads/s2001wincrown/dcm-flutter/total?style=for-the-badge&color=blue) [![project](https://img.shields.io/badge/project-grey?style=for-the-badge)](https://github.com/orgs/s2001wincrown/projects/3)

![](https://m3-markdown-badges.vercel.app/stars/7/2/s2001wincrown/dcm-flutter)
![](https://m3-markdown-badges.vercel.app/issues/1/2/s2001wincrown/dcm-flutter)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Windows/windows3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Linux/linux3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/macOS/macos3.svg)
![](https://ziadoua.github.io/m3-Markdown-Badges/badges/Android/android3.svg)

支持平台：Windows、macOS、Linux、Android、iOS 和 Web。

## 产品界面展示

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

## 应用启动与 CMS 内容同步

1. 从 GitHub Releases 页面下载适用于当前平台的安装包或应用程序：<https://github.com/s2001wincrown/dcm-flutter/releases>。
2. 安装并启动应用。首次启动时，应用界面可能先显示黑屏，这属于正常状态，系统会自动与演示 CMS 系统 http://121.40.137.228:8080/demo 同步内容。
3. 内容同步完成后，应用会自动进入播放状态，开始按照当前节目内容进行展示。
4. 如果需要切换播放内容，请先登录 CMS 演示系统，用户名：`DEMOUser`，密码：`DEMOUser`。
5. 在 Calendar 功能中切换系统预置的 Playlist。
6. 打开 Player 功能，进入 Player 列表（见 `./screenshots/cms2.png`），选择需要更新的 Player，再点击 `Update Now`，将最新内容推送到 Player。
7. Player 接收到更新后会立即切换到新的播放内容。

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

### 使用 Anime4K 着色器

参考 [Anime4K](https://github.com/bloc97/Anime4K) 官方的 GLSL/MPV 安装教程, 下载 template files.

**顶部菜单 -> 应用偏好设置 -> 存储 -> 打开应用数据文件夹**, 把 `mpv.conf`, `input.conf`, `shaders 文件夹` 复制到数据文件夹下.

启用 **应用偏好设置 -> 播放器 -> 允许 libmpv 使用配置文件** 选项, 重启应用.

## 开发说明

如需在本地构建并运行此项目，首先请根据 [官方教程](https://docs.flutter.dev/get-started/install/) 配置 Flutter 环境，并使用不低于 **3.29.0** 的 Flutter 版本。

环境准备完成后，可执行以下命令安装所需依赖：

- `flutter pub get`
- `dart run whisper4dart:setup --prebuilt`

### Windows

在构建 Windows 版本前，先准备 `libmpv` 运行时依赖：

- `dart run libmpv_dart:setup --platform windows`

随后生成 Windows 可执行程序：

- `flutter build windows`

### Linux

配置完 Flutter 后，请通过系统包管理器或其他方式安装 `libmpv-dev`。

生成 Linux 可执行程序：

- `flutter build linux`

### macOS

生成 macOS 可执行程序：

- `flutter build macos`

### Android

> 请在平板设备上运行。

生成 APK 安装包：

- `flutter build apk`

## 参与贡献

欢迎参与本项目的建设。如果您在使用过程中发现问题、希望反馈缺陷或提出功能建议，请 [新建一个 issue](https://github.com/s2001wincrown/dcm-flutter/issues/new)。

我们也非常欢迎通过 Pull Request 提交代码改进、平台适配与新功能支持。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=s2001wincrown/dcm-flutter&type=Date)](https://star-history.com/#s2001wincrown/dcm-flutter&Date)
