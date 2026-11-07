Windows installer packaging
==========================

This folder contains helper scripts to create Windows distributables for `dcmplayer`.

Prerequisites
- `flutter` and `cmake` available on PATH (or Visual Studio's CMake as fallback)
- `flutter build windows` has been run and produced `build/windows/x64`

Create packages
1. Build the app (Release):

```powershell
flutter build windows
```

2. Run the packaging helper (this invokes CPack via CMake):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\package_windows.ps1
```

Outputs
- ZIP archive with the bundle will be created in `build/windows/x64`
- If NSIS (`makensis`) is present, an NSIS installer `.exe` will also be produced

Notes
- You can customize installer metadata in `windows/CMakeLists.txt` under the CPack section.
