import 'dart:async';
import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/services/content_sync_background_service.dart';
import 'package:dcm/backend/services/player_register_impl.dart';
import 'package:dcm/backend/utils/disk_manager.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class InitialSetupPage extends StatefulWidget {
  const InitialSetupPage({
    required this.onCompleted,
    this.reloadSettings = false,
    super.key,
  });

  final void Function(BuildContext context) onCompleted;
  final bool reloadSettings;

  @override
  State<InitialSetupPage> createState() => _InitialSetupPageState();
}

class _InitialSetupPageState extends State<InitialSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _playerName = TextEditingController(
      text: 'Player-${DateTime.now().microsecondsSinceEpoch}');
  final _location = TextEditingController();
  final _organization = TextEditingController(text: 'DEMO');
  final _channel = TextEditingController(text: 'default');
  final _settingsGroup = TextEditingController(text: '3');
  final _httpRootLink = TextEditingController();
  bool _saving = false;
  bool _initializing = true;
  bool _isCheckingRemovableStorage = false;
  Timer? _removableStorageTimer;
  Set<String> _knownRemovableStoragePaths = {};

  @override
  void initState() {
    super.initState();
    KeyMapHelper.keyBindinglock++;
    _initializeSetup();
  }

  Future<void> _initializeSetup() async {
    final storagePaths = await DiskManager.getRemovableStoragePaths();
    _knownRemovableStoragePaths =
        storagePaths.map(_normalizeStoragePath).toSet();
    final imported = await _importRemovableServerSettings(storagePaths);
    if (!imported) {
      await _loadServerSettings();
      if (!mounted) return;
      setState(() => _initializing = false);
      _startRemovableStorageMonitoring();
      return;
    }

    if (!mounted) return;
    await _loadServerSettings();
    if (!mounted) return;
    setState(() => _initializing = false);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _save();
  }

  String _normalizeStoragePath(String storagePath) {
    final normalized = path.normalize(storagePath);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  void _startRemovableStorageMonitoring() {
    _removableStorageTimer?.cancel();
    _removableStorageTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkForNewRemovableStorage(),
    );
  }

  Future<void> _checkForNewRemovableStorage() async {
    if (!mounted || _saving || _initializing || _isCheckingRemovableStorage) {
      return;
    }

    _isCheckingRemovableStorage = true;
    try {
      final storagePaths = await DiskManager.getRemovableStoragePaths();
      if (!mounted) return;

      final currentPaths = storagePaths.map(_normalizeStoragePath).toSet();
      final newPaths = storagePaths
          .where((storagePath) => !_knownRemovableStoragePaths
              .contains(_normalizeStoragePath(storagePath)))
          .toList();
      _knownRemovableStoragePaths = currentPaths;

      if (newPaths.isEmpty) return;
      final imported = await _importRemovableServerSettings(newPaths);
      if (!imported || !mounted || _saving) return;

      await _loadServerSettings();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (mounted && !_saving) await _save(fromRemovableStorage: true);
    } on Object catch (error, stackTrace) {
      logE('Failed to check newly mounted storage: $error', error, stackTrace);
    } finally {
      _isCheckingRemovableStorage = false;
    }
  }

  Future<bool> _importRemovableServerSettings(
      Iterable<String> storagePaths) async {
    final appDataPath = App().dataPath;
    final targetPath =
        path.join(appDataPath, PlayerRegisterImpl.serverConfigFileName);

    for (final storagePath in storagePaths) {
      final sourcePath =
          path.join(storagePath, PlayerRegisterImpl.serverConfigFileName);
      if (path.equals(path.normalize(sourcePath), path.normalize(targetPath))) {
        continue;
      }

      final source = File(sourcePath);
      if (!await source.exists()) continue;

      try {
        final serverFile = IniFile();
        await serverFile.loadFile(sourcePath);
        if (serverFile.sections.isEmpty) continue;

        final settings = await PlayerRegisterImpl.getPlayerInformation(
          path.dirname(sourcePath),
        );
        final uri = Uri.tryParse(settings.pHttpLink.trim());
        if (uri == null ||
            !uri.isAbsolute ||
            uri.host.isEmpty ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          continue;
        }

        await Directory(appDataPath).create(recursive: true);
        await source.copy(targetPath);
        logI('Imported Server.txt from removable storage: $sourcePath');
        return true;
      } on FileSystemException catch (error, stackTrace) {
        logE(
          'Failed to import Server.txt from $sourcePath: $error',
          error,
          stackTrace,
        );
      }
    }

    return false;
  }

  Future<void> _loadServerSettings() async {
    final serverFile = File(
      path.join(App().dataPath, PlayerRegisterImpl.serverConfigFileName),
    );
    if (!await serverFile.exists()) return;

    final settings = await PlayerRegisterImpl.getPlayerInformation(
      App().dataPath,
    );
    if (!mounted) return;
    _playerName.text = settings.pPlayerName.isEmpty
        ? 'Player-${DateTime.now().microsecondsSinceEpoch}'
        : settings.pPlayerName;
    _location.text = settings.pLocation;
    _organization.text =
        settings.pOrganization.isEmpty ? 'DEMO' : settings.pOrganization;
    _channel.text = settings.channel.isEmpty ? 'default' : settings.channel;
    _settingsGroup.text = settings.pSettingsGroup.toString();
    _httpRootLink.text = settings.pHttpLink;
  }

  @override
  void dispose() {
    _removableStorageTimer?.cancel();
    KeyMapHelper.keyBindinglock--;
    _playerName.dispose();
    _location.dispose();
    _organization.dispose();
    _channel.dispose();
    _settingsGroup.dispose();
    _httpRootLink.dispose();
    super.dispose();
  }

  Future<void> _save({bool fromRemovableStorage = false}) async {
    if (_saving || (_isCheckingRemovableStorage && !fromRemovableStorage)) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final httpRootLink = _httpRootLink.text.trim();
    final uri = Uri.tryParse(httpRootLink);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return;
    }

    final settingsGroup = int.tryParse(_settingsGroup.text.trim());
    if (settingsGroup == null) return;

    setState(() => _saving = true);
    final organization = _organization.text.trim();
    final playerName = _playerName.text.trim();
    final location = _location.text.trim();
    try {
      await PlayerRegisterImpl.genPlayerInformation(
        App().dataPath,
        playerName: playerName.isEmpty ? null : playerName,
        location: location.isEmpty ? null : location,
        organization: organization.isEmpty ? null : organization,
        channel: _channel.text.trim(),
        settingsGroup: settingsGroup,
        httpRootLink: _httpRootLink.text.trim(),
      );
      if (widget.reloadSettings) {
        await resetPlayerSettings();
        final contentTypesFile =
            File(path.join(App().dataPath, 'ContentTypes.xml'));
        if (await contentTypesFile.exists()) {
          await contentTypesFile.delete();
        }
      }
      await _completeSetup();
    } on Object catch (error, stackTrace) {
      logE('Failed to save initial player settings: $error', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存初始化设置失败'.l10n)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveLocalPlayer() async {
    if (_saving || _initializing || _isCheckingRemovableStorage) return;
    setState(() => _saving = true);
    try {
      final appDataPath = App().dataPath;
      AppGlobal.appDataPath = appDataPath;
      AppGlobal.configFile = path.join(appDataPath, configFILENAME);
      AppGlobal.autoContentUpdate = false;
      await AppGlobal.genConfigFile(AppGlobal.appDataPath);
      await _completeSetup();
    } on Object catch (error, stackTrace) {
      logE('Failed to create local player configuration: $error', error,
          stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建本地播放器配置失败'.l10n)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _completeSetup() async {
    _removableStorageTimer?.cancel();
    App().needsInitialSetup = false;
    bool checked = await checkAppSetting();
    await loadAppSetting(App().uniqueKey);
    if (!checked && AppGlobal.autoContentUpdate) {
      // Ensure globalPlayer is initialized from CMS or local fallback
      await initGlobalPlayer();
    }
    await ContentSyncBackgroundService.instance.init();
    if (mounted) widget.onCompleted(context);
  }

  void _cancel() {
    if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? '请输入此项'.l10n : null;
  }

  String? _validateHttpRootLink(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入此项'.l10n;
    }

    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.isAbsolute) {
      return '请输入合法的内容管理系统网址'.l10n;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return '网址必须以 http:// 或 https:// 开头'.l10n;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text('播放器初始化'.l10n,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('请输入服务器和播放器信息以完成首次配置。'.l10n),
                    if (_initializing) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text('正在检查移动存储中的服务器配置…'.l10n),
                    ],
                    const SizedBox(height: 24),
                    _field(_playerName, '播放器名称'.l10n, required: false),
                    _field(_location, '地点'.l10n, required: false),
                    _field(_organization, '组织'.l10n, required: false),
                    /*_field(_channel, '频道'.l10n, required: false),
                    _field(_settingsGroup, '设置组'.l10n,
                        keyboardType: TextInputType.number),*/
                    _field(
                      _httpRootLink,
                      '内容管理系统网址'.l10n,
                      keyboardType: TextInputType.url,
                      validator: _validateHttpRootLink,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ||
                              _initializing ||
                              _isCheckingRemovableStorage
                          ? null
                          : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text('保存并继续'.l10n),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saving ||
                              _initializing ||
                              _isCheckingRemovableStorage
                          ? null
                          : _saveLocalPlayer,
                      icon: const Icon(Icons.play_arrow),
                      label: Text('Local Player'.l10n),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _cancel,
                      icon: const Icon(Icons.close),
                      label: Text('取消并退出'.l10n),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator ?? (required ? _required : null),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
