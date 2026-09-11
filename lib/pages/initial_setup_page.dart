import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/keymap_helper.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/services/content_sync_background_service.dart';
import 'package:dcm/backend/services/player_register_impl.dart';
import 'package:dcm/backend/utils/l10n_utils.dart';
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

  @override
  void initState() {
    super.initState();
    KeyMapHelper.keyBindinglock++;
    _loadServerSettings();
  }

  Future<void> _loadServerSettings() async {
    final serverFile = File(
      path.join(App().dataPath, PlayerRegisterImpl.serverConfigFileName),
    );
    if (!await serverFile.exists()) return;

    final settings = await PlayerRegisterImpl.getPlayerInformation(
      App().dataPath,
    );
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
    KeyMapHelper.keyBindinglock--;
    _playerName.dispose();
    _location.dispose();
    _organization.dispose();
    _channel.dispose();
    _settingsGroup.dispose();
    _httpRootLink.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final settingsGroup = int.tryParse(_settingsGroup.text.trim());
    if (settingsGroup == null) return;

    setState(() => _saving = true);
    await PlayerRegisterImpl.genPlayerInformation(
      App().dataPath,
      playerName: _playerName.text.trim(),
      location: _location.text.trim(),
      organization: _organization.text.trim(),
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
                    const SizedBox(height: 24),
                    _field(_playerName, '播放器名称'.l10n, required: false),
                    _field(_location, '地点'.l10n, required: false),
                    /*_field(_organization, '组织'.l10n, required: false),
                    _field(_channel, '频道'.l10n, required: false),
                    _field(_settingsGroup, '设置组'.l10n,
                        keyboardType: TextInputType.number),*/
                    _field(_httpRootLink, '内容管理系统网址'.l10n,
                        keyboardType: TextInputType.url),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
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

  Widget _field(TextEditingController controller, String label,
      {TextInputType? keyboardType, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: required ? _required : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
