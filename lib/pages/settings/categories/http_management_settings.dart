import 'dart:io';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/services/http_management_server.dart';
import 'package:flutter/material.dart';

class HttpManagementSettingsPage extends StatefulWidget {
  const HttpManagementSettingsPage({super.key});

  @override
  State<HttpManagementSettingsPage> createState() =>
      _HttpManagementSettingsPageState();
}

class _HttpManagementSettingsPageState
    extends State<HttpManagementSettingsPage> {
  bool _obscureToken = true;
  bool _saving = false;

  Future<void> _rotateToken() async {
    setState(() => _saving = true);
    try {
      App().settings.httpManagementToken = HttpManagementServer.generateToken();
      await App().saveSettings();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('管理令牌已更新')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存管理令牌失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<String>> _managementUrls() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    return [
      for (final interface in interfaces)
        for (final address in interface.addresses)
          'http://${address.address}:${HttpManagementServer.defaultPort}'
    ];
  }

  @override
  Widget build(BuildContext context) {
    final token = App().settings.httpManagementToken;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'HTTP 管理服务',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          '在同一网络的浏览器中打开以下地址。所有管理 API 均要求使用管理令牌认证；请勿将令牌分享给不受信任的用户。',
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<String>>(
          future: _managementUrls(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('读取网络地址失败：${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            if (snapshot.data!.isEmpty) {
              return const Text('未发现可供局域网访问的 IPv4 地址。');
            }
            return SelectableText(snapshot.data!.join('\n'));
          },
        ),
        const SizedBox(height: 20),
        TextFormField(
          key: ValueKey(token),
          initialValue: token,
          readOnly: true,
          obscureText: _obscureToken,
          decoration: InputDecoration(
            labelText: '管理令牌',
            suffixIcon: IconButton(
              tooltip: _obscureToken ? '显示令牌' : '隐藏令牌',
              onPressed: () => setState(() => _obscureToken = !_obscureToken),
              icon: Icon(
                _obscureToken ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving ? null : _rotateToken,
            icon: const Icon(Icons.refresh),
            label: const Text('重新生成令牌'),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '温度传感器、系统网络/时间配置、硬件亮度与分辨率、固件升级取决于设备平台及厂商接口；未提供平台支持的项目会由 API 明确报告为不可用。',
        ),
      ],
    );
  }
}
