import 'dart:async';
import 'dart:io';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:disk_space_2/disk_space_2.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 磁盘信息模型
class DriveInfo {
  final String path;
  final double totalSpace; // 单位: MB
  final double freeSpace; // 单位: MB

  DriveInfo({
    required this.path,
    required this.totalSpace,
    required this.freeSpace,
  });

  /// 获取已用空间
  double get usedSpace => totalSpace - freeSpace;

  /// 获取使用率百分比 (0.0 - 100.0)
  double get usagePercent =>
      totalSpace > 0 ? (usedSpace / totalSpace) * 100 : 0;

  @override
  String toString() {
    return 'Drive: $path | Total: ${totalSpace.toStringAsFixed(2)} MB | Free: ${freeSpace.toStringAsFixed(2)} MB | Usage: ${usagePercent.toStringAsFixed(1)}%';
  }
}

/// 统一的磁盘管理工具类
class DiskManager {
  /// Returns mount paths for removable storage without querying disk capacity.
  static Future<List<String>> getRemovableStoragePaths() async {
    if (Platform.isAndroid) {
      return _getAndroidRemovablePaths();
    }
    if (Platform.isWindows) {
      return _getWindowsRemovablePaths();
    }
    if (Platform.isMacOS || Platform.isLinux) {
      return _getUnixRemovablePaths();
    }
    return [];
  }

  /// 获取所有可移除的存储驱动器及其空间信息
  static Future<List<DriveInfo>> getRemovableDrivesWithSpace() async {
    final paths = await getRemovableStoragePaths();

    // 2. 获取每个路径的磁盘空间信息
    List<DriveInfo> drives = [];
    for (var path in paths) {
      try {
        // disk_space 插件支持传入特定路径来获取该分区的空间
        double total = await DiskSpace.getTotalDiskSpace ?? 0;
        double free = await DiskSpace.getFreeDiskSpaceForPath(path) ?? 0;

        drives.add(DriveInfo(path: path, totalSpace: total, freeSpace: free));
      } catch (e) {
        logE('获取 $path 空间信息失败: $e');
      }
    }

    return drives;
  }

  // --- Android 平台实现 ---
  static Future<List<String>> _getAndroidRemovablePaths() async {
    List<String> paths = [];
    try {
      List<Directory>? externalDirs = await getExternalStorageDirectories();
      if (externalDirs != null) {
        for (var dir in externalDirs) {
          final androidIndex = dir.path.indexOf('/Android');
          if (androidIndex < 0) continue;
          final rootPath = dir.path.substring(0, androidIndex);
          if (rootPath == '/storage/emulated/0' ||
              rootPath.startsWith('/storage/emulated/') ||
              rootPath == '/storage/self/primary') {
            continue;
          }
          if (!paths.contains(rootPath)) paths.add(rootPath);
        }
      }
    } catch (e) {
      logE('Android 扫描失败: $e');
    }
    return paths;
  }

  // --- Windows 平台实现 ---
  static Future<List<String>> _getWindowsRemovablePaths() async {
    List<String> drives = [];
    try {
      final result = await Process.run(
          'wmic', ['logicaldisk', 'where', 'DriveType=2', 'get', 'DeviceID']);
      if (result.exitCode == 0) {
        List<String> lines = result.stdout.toString().trim().split('\n');
        for (var line in lines) {
          String drive = line.trim();
          if (drive.isNotEmpty && drive.endsWith(':')) drives.add(drive);
        }
      }
    } catch (e) {
      logW('WMIC removable drive scan failed, trying PowerShell: $e');
    }

    if (drives.isEmpty) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' | "
              'Select-Object -ExpandProperty DeviceID',
        ]);
        if (result.exitCode == 0) {
          drives = result.stdout
              .toString()
              .split(RegExp(r'\r?\n'))
              .map((line) => line.trim())
              .where((drive) => drive.endsWith(':'))
              .toList();
        } else {
          logE('PowerShell removable drive scan failed: ${result.stderr}');
        }
      } on Object catch (error, stackTrace) {
        logE('Windows removable drive scan failed: $error', error, stackTrace);
      }
    }
    return drives;
  }

  // --- macOS / Linux 平台实现 ---
  static Future<List<String>> _getUnixRemovablePaths() async {
    List<String> mounts = [];
    try {
      final result = await Process.run('df', ['-h']);
      if (result.exitCode == 0) {
        for (var line in result.stdout.toString().split('\n')) {
          if (line.contains('/Volumes/') ||
              line.contains('/media/') ||
              line.contains('/mnt/')) {
            List<String> parts = line.split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              String mountPoint = parts.last;
              if (!mounts.contains(mountPoint)) mounts.add(mountPoint);
            }
          }
        }
      }
    } catch (e) {
      logE('Unix 扫描失败: $e');
    }
    return mounts;
  }
}

enum StorageAction { mounted, unmounted }

class StorageEvent {
  final StorageAction action;
  final String path;

  StorageEvent(this.action, this.path);

  @override
  String toString() => '${action.name.toUpperCase()}: $path';
}

class StorageMonitor {
  static const MethodChannel _channel =
      MethodChannel('com.app/storage_monitor');

  final StreamController<StorageEvent> _controller =
      StreamController.broadcast();
  Timer? _pollingTimer;

  // 🌟 核心：在内存中维护一份当前已挂载驱动器的路径集合
  Set<String> _currentMountedPaths = {};

  bool _isRunning = false;

  /// 获取事件流
  Stream<StorageEvent> get onStorageChanged => _controller.stream;

  /// 🌟 实时查询某个路径是否已挂载（纯内存查询，极速响应）
  bool isMounted(String path) {
    // 为了兼容不同平台的路径格式（例如 Windows 的 'E:' 和 'E:\'）
    // 我们同时检查原路径和去掉尾部斜杠的路径
    final normalizedPath = path.replaceAll(RegExp(r'[\\/]+$'), '');
    return _currentMountedPaths.contains(path) ||
        _currentMountedPaths.contains(normalizedPath);
  }

  /// 开始监控
  void start({Duration pollingInterval = const Duration(seconds: 2)}) async {
    if (_isRunning) return;
    _isRunning = true;

    // 启动时立即初始化一次状态
    await _refreshMountedPaths();

    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：监听原生 MethodChannel 事件
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onStorageEvent') {
          final Map<dynamic, dynamic> args = call.arguments as Map;
          final action = args['action'] == 'mounted'
              ? StorageAction.mounted
              : StorageAction.unmounted;
          final path = args['path'] as String;

          // 🌟 同步更新内存缓存
          if (action == StorageAction.mounted) {
            _currentMountedPaths.add(path);
          } else {
            _currentMountedPaths.remove(path);
          }

          _controller.add(StorageEvent(action, path));
        }
      });
    } else {
      // 桌面端：启动轮询机制
      _startPolling(pollingInterval);
    }
  }

  /// 停止监控
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _channel.setMethodCallHandler(null);
    _pollingTimer?.cancel();
    _currentMountedPaths.clear();
  }

  /// 释放资源
  void dispose() {
    stop();
    _controller.close();
  }

  // --- 内部方法：刷新挂载路径缓存 ---
  Future<void> _refreshMountedPaths() async {
    try {
      final drives = await DiskManager.getRemovableDrivesWithSpace();
      _currentMountedPaths = drives.map((d) => d.path).toSet();
    } catch (e) {
      logE('刷新挂载路径失败: $e');
    }
  }

  // --- 桌面端轮询逻辑 ---
  void _startPolling(Duration interval) {
    _pollingTimer = Timer.periodic(interval, (_) async {
      final oldPaths = Set<String>.from(_currentMountedPaths);

      // 重新扫描并刷新缓存
      await _refreshMountedPaths();

      // 检测插入
      for (var path in _currentMountedPaths) {
        if (!oldPaths.contains(path)) {
          _controller.add(StorageEvent(StorageAction.mounted, path));
        }
      }

      // 检测拔出
      for (var path in oldPaths) {
        if (!_currentMountedPaths.contains(path)) {
          _controller.add(StorageEvent(StorageAction.unmounted, path));
        }
      }
    });
  }
}
