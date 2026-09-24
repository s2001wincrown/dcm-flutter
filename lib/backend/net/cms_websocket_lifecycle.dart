import 'dart:async';

import 'package:flutter/widgets.dart';

import 'cms_websocket_service.dart';

class CmsWebSocketLifecycleBinding with WidgetsBindingObserver {
  CmsWebSocketLifecycleBinding(this.service);

  final CmsWebSocketService service;
  bool _bound = false;

  void bind() {
    if (_bound) {
      return;
    }
    _bound = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(service.connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(service.connect());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(service.disconnect());
    }
  }

  Future<void> dispose() async {
    if (_bound) {
      WidgetsBinding.instance.removeObserver(this);
      _bound = false;
    }
    await service.dispose();
  }
}
