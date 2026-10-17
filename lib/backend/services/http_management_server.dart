import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/app_global.dart';
import 'package:dcm/backend/models/day_info_data.dart';
import 'package:dcm/backend/models/dcmfile_data.dart';
import 'package:dcm/backend/models/eventitem_data.dart';
import 'package:dcm/backend/models/layout_data.dart';
import 'package:dcm/backend/models/product_data.dart';
import 'package:dcm/backend/models/zone_data.dart';
import 'package:dcm/backend/net/player_log_impl.dart';
import 'package:dcm/backend/providers/player_screen_provider.dart';
import 'package:dcm/backend/services/channel_schedule_impl.dart';
import 'package:dcm/backend/services/content_file_impl.dart';
import 'package:dcm/backend/services/content_sync_background_service.dart';
import 'package:dcm/backend/services/integrity_check.dart';
import 'package:dcm/backend/services/schedulelist_impl.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/xml_settings/dcmfile_Impl.dart';
import 'package:dcm/backend/xml_settings/eventfile_impl.dart';
import 'package:dcm/backend/xmlfile/inifile.dart';
import 'package:disk_space_2/disk_space_2.dart';
import 'package:path/path.dart' as path;
import 'package:pair/pair.dart';

class HttpManagementServer {
  HttpManagementServer({this.port = defaultPort});

  static const int defaultPort = 8765;
  static const int _maxJsonBytes = 1024 * 1024;
  static const int _maxUploadBytes = 2 * 1024 * 1024 * 1024;
  static const Map<String, String> _dcmSettings = {
    'Global Setting.Auto Reload Idle Duration': 'Auto Reload Idle Duration',
    'Global Setting.MultiMonitor': 'MultiMonitor',
    'Global Setting.VideoSetting': 'VideoSetting',
    'Global Setting.Video_Render': 'Video_Render',
    'Global Setting.MaxContentDuration': 'MaxContentDuration',
    'Global Setting.MaxDefaultEvent': 'MaxDefaultEvent',
    'Global Setting.EventMultiGroup': 'EventMultiGroup',
    'Global Setting.PlaybackSettings': 'PlaybackSettings',
    'Global Setting.PlayMode': 'PlayMode',
    'Global Setting.EventTimeout': 'EventTimeout',
    'Global Setting.ZoneThread': 'ZoneThread',
    'Global Setting.Background Color': 'Background Color',
  };

  HttpServer? _server;
  final int port;

  bool get isRunning => _server != null;
  int? get boundPort => _server?.port;

  static String generateToken() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> start() async {
    if (_server != null) return;
    if (App().settings.httpManagementToken.isEmpty) {
      App().settings.httpManagementToken = generateToken();
      await App().saveSettings();
    }

    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    _server = server;
    server.listen(_handleRequest, onError: (Object error, StackTrace stack) {
      logE('HTTP management server failed: $error', error, stack);
    });
    logI('HTTP management server listening on port ${server.port}.');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/') {
        await _writeHtml(request.response, _managementPage);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJson(request.response, HttpStatus.ok, {'online': true});
        return;
      }
      if (!_isAuthorized(request)) {
        request.response.headers
            .set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
        await _writeJson(request.response, HttpStatus.unauthorized, {
          'error': 'unauthorized',
          'message': 'A valid Bearer token is required.',
        });
        return;
      }

      final method = request.method;
      final route = request.uri.path;
      if (method == 'GET' && route == '/api/status') {
        await _writeJson(request.response, HttpStatus.ok, await _getStatus());
      } else if (method == 'GET' && route == '/api/capabilities') {
        await _writeJson(request.response, HttpStatus.ok, _getCapabilities());
      } else if (method == 'GET' && route == '/api/settings') {
        await _writeJson(request.response, HttpStatus.ok, _getSettings());
      } else if (method == 'PATCH' && route == '/api/settings') {
        await _updateSettings(request);
      } else if (method == 'POST' && route == '/api/settings/network') {
        await _notSupported(request.response, 'network configuration',
            'No platform network-configuration adapter is installed.');
      } else if (method == 'POST' && route == '/api/settings/time') {
        await _notSupported(request.response, 'system clock changes',
            'Changing the device clock requires a platform-specific privileged service.');
      } else if (method == 'POST' &&
          (route == '/api/settings/display' ||
              route == '/api/settings/brightness')) {
        await _notSupported(request.response, 'display hardware controls',
            'Brightness, display orientation, split-screen modes, and output resolution are not exposed by this player runtime.');
      } else if (method == 'GET' && route == '/api/playlists') {
        await _writeJson(request.response, HttpStatus.ok, _getPlaylists());
      } else if (method == 'PUT' && route == '/api/playlists/current') {
        await _switchPlaylist(request);
      } else if (method == 'POST' && route == '/api/playlists') {
        await _savePlaylist(request);
      } else if (method == 'POST' && route == '/api/playback/reload') {
        await _reloadPlaylist(request.response);
      } else if (method == 'POST' && route == '/api/playback/insert') {
        await _insertCatalogue(request);
      } else if (method == 'POST' && route == '/api/playback/restore') {
        await _restoreDefault(request.response);
      } else if (method == 'POST' && route == '/api/catalogues') {
        await _saveCatalogue(request);
      } else if (method == 'POST' && route == '/api/schedules/month') {
        await _saveSchedule(request);
      } else if (method == 'POST' && route == '/api/content/upload') {
        await _uploadContent(request);
      } else if (method == 'POST' && route == '/api/content/sync') {
        await _requestContentSync(request.response);
      } else if (method == 'GET' && route == '/api/diagnostics/playback-logs') {
        await _notSupported(request.response, 'playback log download',
            'Playback event logging is not currently implemented by the player.');
      } else if (method == 'POST' && route == '/api/content/validate') {
        await _validateContent(request);
      } else if (method == 'DELETE' && route == '/api/content/expired') {
        await _deleteExpiredContent(request.response);
      } else if (method == 'GET' && route == '/api/diagnostics/screenshot') {
        await _sendScreenshot(request.response);
      } else if (method == 'GET' && route == '/api/diagnostics/logs') {
        await _sendLogs(request.response);
      } else if (method == 'POST' && route == '/api/diagnostics/restart') {
        await _scheduleRestart(request.response);
      } else if (method == 'POST' && route == '/api/diagnostics/firmware') {
        await _notSupported(request.response, 'firmware upgrade',
            'No firmware download, signature-verification, or installation adapter is configured.');
      } else {
        await _writeJson(request.response, HttpStatus.notFound, {
          'error': 'not_found',
          'message': 'No route matches ${request.method} ${request.uri.path}.',
        });
      }
    } on FormatException catch (error) {
      await _writeJson(request.response, HttpStatus.badRequest, {
        'error': 'invalid_request',
        'message': error.message,
      });
    } on UnsupportedError catch (error) {
      await _writeJson(request.response, HttpStatus.notImplemented, {
        'error': 'not_supported',
        'message': error.message,
      });
    } catch (error, stack) {
      logE('HTTP management request failed: $error', error, stack);
      try {
        await _writeJson(request.response, HttpStatus.internalServerError, {
          'error': 'internal_error',
          'message': 'The request could not be completed.',
        });
      } catch (writeError, writeStack) {
        logE('Failed to return HTTP management error response: $writeError',
            writeError, writeStack);
        try {
          await request.response.close();
        } catch (closeError, closeStack) {
          logE('Failed to close HTTP management response: $closeError',
              closeError, closeStack);
        }
      }
    }
  }

  bool _isAuthorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (header == null || !header.startsWith('Bearer ')) return false;
    final provided = utf8.encode(header.substring(7));
    final expected = utf8.encode(App().settings.httpManagementToken);
    if (provided.length != expected.length || expected.isEmpty) return false;
    var difference = 0;
    for (var index = 0; index < expected.length; index++) {
      difference |= provided[index] ^ expected[index];
    }
    return difference == 0;
  }

  Future<Map<String, dynamic>> _getStatus() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = [
      for (final interface in interfaces)
        for (final address in interface.addresses)
          {'interface': interface.name, 'address': address.address}
    ];
    final storage = <String, dynamic>{'available': false};
    try {
      final freeSpaceMb =
          await DiskSpace.getFreeDiskSpaceForPath(App().dataPath);
      storage
        ..['available'] = freeSpaceMb != null
        ..['freeSpaceMb'] = freeSpaceMb;
    } catch (error) {
      storage['error'] = error.toString();
    }

    return {
      'online': true,
      'timestamp': DateTime.now().toIso8601String(),
      'device': Platform.operatingSystem,
      'addresses': addresses,
      'playing': {
        'title': App().playingTitle,
        'isPlaying': App().player.state.playing,
        'volume': App().player.state.volume,
        'playlist': ScheduleList().currEvent,
      },
      'storage': storage,
      'temperatureC': null,
      'temperatureAvailable': false,
      'display': {
        'physicalWidth':
            PlatformDispatcher.instance.views.first.physicalSize.width,
        'physicalHeight':
            PlatformDispatcher.instance.views.first.physicalSize.height,
        'devicePixelRatio':
            PlatformDispatcher.instance.views.first.devicePixelRatio,
      },
    };
  }

  Map<String, dynamic> _getCapabilities() {
    final supported = <String>[
      'status',
      'player-volume',
      'dcm.dat-settings',
      'playlist-management',
      'split-screen-layout',
      'catalogue-authoring',
      'schedule-authoring',
      'content-upload',
      'manual-cms-sync',
      'content-validation',
      'expired-content-cleanup',
      'screenshot',
      'log-download',
      'player-restart',
    ];
    final unsupported = <String, String>{
      'temperature': 'No thermal sensor API is available in the app.',
      'network-configuration':
          'Requires a platform-specific adapter and elevated permissions.',
      'system-time': 'Requires a platform-specific privileged time service.',
      'brightness': 'No display brightness control is exposed by the player.',
      'orientation': 'No remote display orientation adapter is configured.',
      'resolution': 'No remote display mode adapter is configured.',
      'playback-logs':
          'Playback event logging is not currently implemented by the player.',
      'firmware-upgrade':
          'No signed firmware installation workflow is configured.',
    };
    if (Platform.isIOS) {
      supported.remove('player-restart');
      unsupported['player-restart'] =
          'iOS does not allow applications to remotely restart the device.';
    }
    return {'supported': supported, 'unsupported': unsupported};
  }

  Map<String, dynamic> _getSettings() => {
        'player': {
          'volume': App().player.state.volume,
          'defaultVolume': App().settings.defaultVolume,
          'autoPlay': App().settings.autoPlay,
        },
        'dcm': {
          'autoReloadIdleDuration': AppGlobal.autoReloadDuration,
          'multiMonitor': AppGlobal.multiMonitor,
          'videoSetting': AppGlobal.videoSetting,
          'videoRender': AppGlobal.videoRender,
          'maxContentDuration': AppGlobal.maxContentDuration,
          'maxDefaultEvent': AppGlobal.maxDefaultEvent,
          'multiGroup': AppGlobal.multiGroup,
          'loopMethod': AppGlobal.loopMethod,
          'playMode': AppGlobal.playMode,
          'eventTimeout': AppGlobal.eventTimeout,
          'maxZoneThread': AppGlobal.maxZoneThread,
          'backgroundColor': AppGlobal.clrBGColor,
        },
      };

  Future<void> _updateSettings(HttpRequest request) async {
    final body = await _readJson(request);
    final unknownTopLevel =
        body.keys.where((key) => key != 'player' && key != 'dcm').toList();
    if (unknownTopLevel.isNotEmpty) {
      throw FormatException(
          'Unsupported settings section: ${unknownTopLevel.first}.');
    }
    final player = body['player'];
    if (player != null) {
      if (player is! Map<String, dynamic>) {
        throw const FormatException('player must be an object.');
      }
      final unknownPlayerSettings = player.keys
          .where((key) =>
              key != 'volume' && key != 'defaultVolume' && key != 'autoPlay')
          .toList();
      if (unknownPlayerSettings.isNotEmpty) {
        throw FormatException(
            'Unsupported player setting: ${unknownPlayerSettings.first}.');
      }
      if (player.containsKey('volume')) {
        final volume = _number(player['volume'], 'player.volume');
        if (volume < 0 || volume > 100) {
          throw const FormatException(
              'player.volume must be between 0 and 100.');
        }
        App().settings.volume = volume;
        await App().player.setVolume(volume);
      }
      if (player.containsKey('defaultVolume')) {
        final volume = _number(player['defaultVolume'], 'player.defaultVolume');
        if (volume < 0 || volume > 100) {
          throw const FormatException(
              'player.defaultVolume must be between 0 and 100.');
        }
        App().settings.defaultVolume = volume;
      }
      if (player.containsKey('autoPlay')) {
        final autoPlay = player['autoPlay'];
        if (autoPlay is! bool) {
          throw const FormatException('player.autoPlay must be a boolean.');
        }
        App().settings.autoPlay = autoPlay;
      }
      await App().saveSettings();
    }

    final dcm = body['dcm'];
    if (dcm != null) {
      if (dcm is! Map<String, dynamic>) {
        throw const FormatException('dcm must be an object.');
      }
      await _writeDcmSettings(dcm);
    }
    await _writeJson(
        request.response, HttpStatus.ok, {'settings': _getSettings()});
  }

  Future<void> _writeDcmSettings(Map<String, dynamic> values) async {
    final unsupported =
        values.keys.where((key) => !_dcmSettings.containsKey(key));
    if (unsupported.isNotEmpty) {
      throw FormatException('Unsupported dcm setting: ${unsupported.first}.');
    }
    final configPath = path.join(App().dataPath, configFILENAME);
    final configFile = IniFile();
    await configFile.loadFile(configPath);
    for (final entry in values.entries) {
      final stringValue = entry.value.toString();
      final key = _dcmSettings[entry.key]!;
      configFile.writeString('Global Setting', key, stringValue);
      switch (key) {
        case 'Auto Reload Idle Duration':
        case 'MultiMonitor':
        case 'VideoSetting':
        case 'Video_Render':
        case 'MaxDefaultEvent':
        case 'EventMultiGroup':
        case 'PlaybackSettings':
        case 'PlayMode':
        case 'EventTimeout':
        case 'ZoneThread':
        case 'Background Color':
          _integer(entry.value, entry.key);
        case 'MaxContentDuration':
          _number(entry.value, entry.key);
      }
    }
    if (!await configFile.save()) {
      throw FileSystemException('Failed to save dcm.dat', configPath);
    }
    for (final entry in values.entries) {
      final key = _dcmSettings[entry.key]!;
      switch (key) {
        case 'Auto Reload Idle Duration':
          AppGlobal.autoReloadDuration = _integer(entry.value, entry.key);
        case 'MultiMonitor':
          AppGlobal.multiMonitor = _integer(entry.value, entry.key);
        case 'VideoSetting':
          AppGlobal.videoSetting = _integer(entry.value, entry.key);
        case 'Video_Render':
          AppGlobal.videoRender = _integer(entry.value, entry.key);
        case 'MaxContentDuration':
          AppGlobal.maxContentDuration = _number(entry.value, entry.key);
        case 'MaxDefaultEvent':
          AppGlobal.maxDefaultEvent = _integer(entry.value, entry.key);
        case 'EventMultiGroup':
          AppGlobal.multiGroup = _integer(entry.value, entry.key);
        case 'PlaybackSettings':
          AppGlobal.loopMethod = _integer(entry.value, entry.key);
        case 'PlayMode':
          AppGlobal.playMode = _integer(entry.value, entry.key);
        case 'EventTimeout':
          AppGlobal.eventTimeout = _integer(entry.value, entry.key);
        case 'ZoneThread':
          AppGlobal.maxZoneThread = _integer(entry.value, entry.key);
        case 'Background Color':
          AppGlobal.clrBGColor = _integer(entry.value, entry.key);
      }
    }
  }

  List<String> _getPlaylists() {
    if (AppGlobal.dayPath.isEmpty) return [];
    final directory = Directory(AppGlobal.dayPath);
    if (!directory.existsSync()) return [];
    return directory
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => path.extension(file.path).toLowerCase() == '.xml')
        .map((file) => path.basenameWithoutExtension(file.path))
        .toList()
      ..sort();
  }

  Future<void> _switchPlaylist(HttpRequest request) async {
    _requireConfiguredPath(AppGlobal.dayPath, 'Playlist directory');
    final body = await _readJson(request);
    final name = _safeName(body['name'], 'name');
    final playlistPath = path.join(AppGlobal.dayPath, '$name.xml');
    if (!await File(playlistPath).exists()) {
      throw const FormatException('Playlist does not exist.');
    }
    if (!ScheduleList().loadSchedule(playList: name)) {
      throw const FormatException('Playlist could not be loaded.');
    }
    PlayerScreenProvider.instance?.reloadSchedule();
    await _writeJson(request.response, HttpStatus.ok, {'current': name});
  }

  Future<void> _reloadPlaylist(HttpResponse response) async {
    ScheduleList().loadSchedule();
    PlayerScreenProvider.instance?.reloadSchedule();
    await _writeJson(response, HttpStatus.ok, {'reloaded': true});
  }

  Future<void> _insertCatalogue(HttpRequest request) async {
    _requireConfiguredPath(AppGlobal.openPath, 'Catalogue directory');
    final body = await _readJson(request);
    final name = _safeName(body['name'], 'name');
    if (DCMFileImpl.getDCMPath(name, AppGlobal.openPath) == null) {
      throw const FormatException('Catalogue does not exist.');
    }
    final player = PlayerScreenProvider.instance;
    if (player == null) {
      throw UnsupportedError('The player screen is not ready.');
    }
    player.setPlayFile(name);
    await player.playImm();
    await _writeJson(request.response, HttpStatus.ok, {'inserted': name});
  }

  Future<void> _restoreDefault(HttpResponse response) async {
    PlayerScreenProvider.instance?.setPlayFile('');
    ScheduleList().currEvent = '';
    ScheduleList().loadSchedule();
    PlayerScreenProvider.instance?.reloadSchedule();
    await _writeJson(response, HttpStatus.ok, {'restored': true});
  }

  Future<void> _saveCatalogue(HttpRequest request) async {
    _requireConfiguredPath(AppGlobal.openPath, 'Catalogue directory');
    final body = await _readJson(request);
    final name = _safeName(body['name'], 'name');
    final layoutJson = body['layout'];
    if (layoutJson is! Map<String, dynamic>) {
      throw const FormatException('layout must be an object.');
    }
    final width = _integer(layoutJson['width'], 'layout.width');
    final height = _integer(layoutJson['height'], 'layout.height');
    final zoneRects = layoutJson['zones'];
    if (width <= 0 || height <= 0 || zoneRects is! List || zoneRects.isEmpty) {
      throw const FormatException(
          'layout requires positive width/height and a non-empty zones list.');
    }

    final layout = LayoutData()
      ..strLayoutName =
          _optionalString(layoutJson['name'], 'layout.name', 'RemoteLayout')
      ..strLayoutDesc =
          _optionalString(layoutJson['description'], 'layout.description')
      ..iScreenWidth = width
      ..iScreenHeight = height
      ..iNoOfParition = zoneRects.length;
    for (final zone in zoneRects) {
      if (zone is! Map<String, dynamic>) {
        throw const FormatException('Each layout zone must be an object.');
      }
      final left = _number(zone['left'], 'zone.left');
      final top = _number(zone['top'], 'zone.top');
      final zoneWidth = _number(zone['width'], 'zone.width');
      final zoneHeight = _number(zone['height'], 'zone.height');
      if (left < 0 ||
          top < 0 ||
          zoneWidth <= 0 ||
          zoneHeight <= 0 ||
          left + zoneWidth > width ||
          top + zoneHeight > height) {
        throw const FormatException('A layout zone is outside the screen.');
      }
      layout.pZoneRect.add(
        Rect.fromLTWH(left, top, zoneWidth, zoneHeight),
      );
    }

    final products = body['products'];
    if (products is! List || products.isEmpty) {
      throw const FormatException('products must be a non-empty list.');
    }
    final catalogue = DCMFileData()
      ..strCatalogueName = name
      ..strCatalogueDesc = _optionalString(body['description'], 'description')
      ..strLayoutName = layout.strLayoutName
      ..pLayoutDataObj = layout
      ..nQuantity = products.length;
    for (var index = 0; index < products.length; index++) {
      final productJson = products[index];
      if (productJson is! Map<String, dynamic>) {
        throw const FormatException('Each product must be an object.');
      }
      final zones = productJson['zones'];
      if (zones is! List || zones.length != zoneRects.length) {
        throw FormatException(
            'Product $index must define one zone for each layout partition.');
      }
      final product = ProductData()
        ..uiID = index
        ..strProductName = _optionalString(
            productJson['name'], 'products[$index].name', 'Product $index')
        ..strProductDesc = _optionalString(
            productJson['description'], 'products[$index].description')
        ..strImgFile =
            _optionalString(productJson['image'], 'products[$index].image');
      for (var zoneIndex = 0; zoneIndex < zones.length; zoneIndex++) {
        final zoneJson = zones[zoneIndex];
        if (zoneJson is! Map<String, dynamic>) {
          throw const FormatException('Each product zone must be an object.');
        }
        final file = _optionalString(
            zoneJson['file'], 'products[$index].zones[$zoneIndex].file');
        if (file.isEmpty) {
          throw FormatException('Product $index zone $zoneIndex needs a file.');
        }
        product.lstZone.add(ZoneData()
          ..nZoneID = zoneIndex
          ..nZoneType = _integer(zoneJson['type'], 'zone.type')
          ..strZoneFile = file
          ..strZoneOfflineFile =
              _optionalString(zoneJson['offlineFile'], 'zone.offlineFile'));
      }
      catalogue.addProduct(product);
    }

    if (!DCMFileImpl.saveCatalogue(catalogue, name)) {
      throw FileSystemException('Failed to save catalogue', name);
    }
    await _writeJson(request.response, HttpStatus.created, {'name': name});
  }

  Future<void> _savePlaylist(HttpRequest request) async {
    _requireConfiguredPath(AppGlobal.dayPath, 'Playlist directory');
    _requireConfiguredPath(AppGlobal.openPath, 'Catalogue directory');
    final body = await _readJson(request);
    final name = _safeName(body['name'], 'name');
    final itemsJson = body['items'];
    if (itemsJson is! List || itemsJson.isEmpty) {
      throw const FormatException('items must be a non-empty list.');
    }
    final data = EventFileData()
      ..strScheduleName = name
      ..strScheduleDesc = _optionalString(body['description'], 'description')
      ..bAutoPlay = _optionalBool(body['autoPlay'], 'autoPlay', true)
      ..lstPlayList = [];
    for (var index = 0; index < itemsJson.length; index++) {
      final itemJson = itemsJson[index];
      if (itemJson is! Map<String, dynamic>) {
        throw const FormatException('Each playlist item must be an object.');
      }
      final file = _safeName(itemJson['catalogue'], 'items[$index].catalogue');
      if (DCMFileImpl.getDCMPath(file, AppGlobal.openPath) == null) {
        throw FormatException('Catalogue does not exist: $file.');
      }
      final item = EventItemData()
        ..uiID = index
        ..strDCMFile = file
        ..nPlayTimes = _integer(itemJson['playTimes'] ?? 1, 'playTimes');
      data.addPlayList(item);
    }
    if (!EventFileImpl().savePlayList(data, name)) {
      throw FileSystemException('Failed to save playlist', name);
    }
    await _writeJson(request.response, HttpStatus.created, {'name': name});
  }

  Future<void> _saveSchedule(HttpRequest request) async {
    _requireConfiguredPath(AppGlobal.calendarPath, 'Calendar directory');
    final body = await _readJson(request);
    final month = _safeMonth(body['month']);
    final channel = body['channel'] == null || body['channel'] == ''
        ? ''
        : _safeName(body['channel'], 'channel');
    final days = body['days'];
    if (days is! List) {
      throw const FormatException('days must be a list.');
    }
    final schedule = <DayInfoData>[];
    for (final dayJson in days) {
      if (dayJson is! Map<String, dynamic>) {
        throw const FormatException('Each day must be an object.');
      }
      final day = _integer(dayJson['day'], 'day');
      final monthLastDay = DateTime(
        int.parse(month.substring(0, 4)),
        int.parse(month.substring(4, 6)) + 1,
        0,
      ).day;
      if (day < 1 || day > monthLastDay) {
        throw FormatException('day must be between 1 and $monthLastDay.');
      }
      final info = DayInfoData()
        ..day = day
        ..event = _optionalString(dayJson['event'], 'day.event')
        ..info = _optionalString(dayJson['info'], 'day.info')
        ..playMeth = _integer(dayJson['playMethod'] ?? 0, 'playMethod');
      if (info.event.isNotEmpty) {
        _safeName(info.event, 'day.event');
      }
      final events = dayJson['events'];
      if (events != null) {
        if (events is! Map<String, dynamic>) {
          throw const FormatException('day.events must be an object.');
        }
        for (final entry in events.entries) {
          if (entry.value is! String) {
            throw FormatException('day.events.${entry.key} must be a string.');
          }
          if (entry.value.isNotEmpty) {
            _safeName(entry.value, 'day.events.${entry.key}');
          }
        }
        info.arrEvent.addAll(events.entries.map(
          (entry) => Pair<String, String>(entry.key, entry.value as String),
        ));
      }
      schedule.add(info);
    }
    if (!ChannelScheduleImpl().saveSchedule(
      schedule,
      channel,
      strSchedule: path.join(AppGlobal.calendarPath, '$month.xml'),
    )) {
      throw FileSystemException('Failed to save monthly schedule', month);
    }
    await _writeJson(request.response, HttpStatus.created, {'month': month});
  }

  Future<void> _uploadContent(HttpRequest request) async {
    final filename = _safeFilename(request.uri.queryParameters['name']);
    final category = request.uri.queryParameters['category'] ?? '';
    final destination = _contentDirectory(category);
    if (destination.isEmpty) {
      throw const FormatException('Unsupported content category.');
    }

    final file = File(path.join(destination, filename));
    if (await file.exists()) {
      request.response
        ..statusCode = HttpStatus.conflict
        ..headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'error': 'already_exists',
        'message': 'A file with that name already exists.',
      }));
      await request.response.close();
      return;
    }
    await file.parent.create(recursive: true);
    final sink = file.openWrite();
    var length = 0;
    try {
      await for (final chunk in request) {
        length += chunk.length;
        if (length > _maxUploadBytes) {
          throw const FormatException('Upload exceeds the 2 GiB limit.');
        }
        sink.add(chunk);
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    await sink.close();
    await _writeJson(request.response, HttpStatus.created, {
      'name': filename,
      'category': category,
      'bytes': length,
    });
  }

  Future<void> _requestContentSync(HttpResponse response) async {
    if (!ContentSyncBackgroundService.instance.requestImmediateSync()) {
      await _writeJson(response, HttpStatus.serviceUnavailable, {
        'error': 'sync_worker_unavailable',
        'message':
            'The CMS sync worker is not running. Check CMS settings and auto-sync configuration.',
      });
      return;
    }
    await _writeJson(response, HttpStatus.accepted, {
      'accepted': true,
      'message': 'CMS content synchronization was queued.',
    });
  }

  String _contentDirectory(String category) => switch (category) {
        'images' => AppGlobal.imagePath,
        'video' => AppGlobal.vcdPath,
        'web' => AppGlobal.webPath,
        'text' => AppGlobal.textPath,
        'catalogues' => AppGlobal.openPath,
        'playlists' => AppGlobal.dayPath,
        _ => '',
      };

  Future<void> _validateContent(HttpRequest request) async {
    final body = await _readJson(request);
    final kind = body['kind'];
    final name = _safeName(body['name'], 'name');
    bool valid;
    if (kind == 'playlist') {
      _requireConfiguredPath(AppGlobal.dayPath, 'Playlist directory');
      valid = IntegrityCheck(writeLog: false).integrityCheckPlaylist(name);
    } else if (kind == 'catalogue') {
      _requireConfiguredPath(AppGlobal.openPath, 'Catalogue directory');
      valid = IntegrityCheck(writeLog: false).integrityCheckDCMFile(name);
    } else {
      throw const FormatException('kind must be "playlist" or "catalogue".');
    }
    await _writeJson(request.response, HttpStatus.ok, {
      'name': name,
      'kind': kind,
      'valid': valid,
    });
  }

  Future<void> _deleteExpiredContent(HttpResponse response) async {
    final contentFile = ContentFileImpl.empty();
    final deleted = <String, bool>{};
    for (final entry in {
      'calendar': AppGlobal.calendarPath,
      'month': AppGlobal.monthPath,
    }.entries) {
      if (entry.value.isNotEmpty) {
        deleted[entry.key] = await contentFile.deleteMonthContents(entry.value);
      }
    }
    await _writeJson(response, HttpStatus.ok, {'results': deleted});
  }

  Future<void> _sendScreenshot(HttpResponse response) async {
    final image = await App().player.screenshot();
    if (image == null) {
      throw UnsupportedError('The player did not provide a screenshot.');
    }
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('image', 'png')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.add(image);
    await response.close();
  }

  Future<void> _sendLogs(HttpResponse response) async {
    final logFile = File(path.join(App().dataPath, 'logs', 'player.log'));
    if (!await logFile.exists()) {
      throw const FileSystemException('Player log file does not exist.');
    }
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.text
      ..headers.set('Content-Disposition', 'attachment; filename="player.log"')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    await response.addStream(logFile.openRead());
    await response.close();
  }

  Future<void> _scheduleRestart(HttpResponse response) async {
    if (Platform.isIOS) {
      await _notSupported(response, 'device restart',
          'iOS does not allow applications to remotely restart the device.');
      return;
    }
    await _writeJson(response, HttpStatus.accepted, {'restarting': true});
    unawaited(Future<void>.delayed(const Duration(milliseconds: 500), () async {
      final succeeded = await PlayerLogImpl.restartAction();
      if (!succeeded) {
        logE('Remote restart request did not complete successfully.');
      }
    }));
  }

  Future<void> _notSupported(
      HttpResponse response, String feature, String reason) async {
    await _writeJson(response, HttpStatus.notImplemented, {
      'error': 'not_supported',
      'feature': feature,
      'message': reason,
    });
  }

  Future<Map<String, dynamic>> _readJson(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > _maxJsonBytes) {
        throw const FormatException('JSON request exceeds the 1 MiB limit.');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Request body must be a JSON object.');
    }
    return decoded;
  }

  String _safeName(Object? value, String field) {
    if (value is! String ||
        value.isEmpty ||
        value == '.' ||
        value == '..' ||
        path.basename(value) != value ||
        value.contains('/') ||
        value.contains(r'\')) {
      throw FormatException('$field must be a plain, non-empty name.');
    }
    return value;
  }

  String _optionalString(Object? value, String field,
      [String defaultValue = '']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    throw FormatException('$field must be a string.');
  }

  bool _optionalBool(Object? value, String field, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    throw FormatException('$field must be a boolean.');
  }

  String _safeFilename(String? value) {
    if (value == null ||
        value.isEmpty ||
        value == '.' ||
        value == '..' ||
        path.basename(value) != value ||
        value.contains('/') ||
        value.contains(r'\')) {
      throw const FormatException('name must be a plain file name.');
    }
    return value;
  }

  void _requireConfiguredPath(String value, String label) {
    if (value.isEmpty) {
      throw UnsupportedError('$label is not configured on this device.');
    }
  }

  String _safeMonth(Object? value) {
    if (value is! String || !RegExp(r'^\d{6}$').hasMatch(value)) {
      throw const FormatException('month must use YYYYMM format.');
    }
    final year = int.parse(value.substring(0, 4));
    final month = int.parse(value.substring(4, 6));
    if (year < 2000 || month < 1 || month > 12) {
      throw const FormatException('month is not a valid YYYYMM value.');
    }
    return value;
  }

  double _number(Object? value, String field) {
    if (value is! num || !value.isFinite) {
      throw FormatException('$field must be a finite number.');
    }
    return value.toDouble();
  }

  int _integer(Object? value, String field) {
    if (value is! num || !value.isFinite || value != value.toInt()) {
      throw FormatException('$field must be an integer.');
    }
    return value.toInt();
  }

  Future<void> _writeJson(
      HttpResponse response, int status, Object value) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.write(jsonEncode(value));
    await response.close();
  }

  Future<void> _writeHtml(HttpResponse response, String html) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('X-Content-Type-Options', 'nosniff')
      ..headers.set('X-Frame-Options', 'DENY')
      ..headers.set('Content-Security-Policy',
          "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'");
    response.write(html);
    await response.close();
  }

  static const String _managementPage = r'''
<!doctype html>
<html lang="zh-CN">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>DCM 播放机管理</title>
<style>
body{font:16px system-ui,sans-serif;max-width:960px;margin:2rem auto;padding:0 1rem;background:#f4f6fa;color:#172033}
header,section{background:white;border-radius:12px;padding:1.2rem;margin:1rem 0;box-shadow:0 2px 10px #14213d12}
h1{margin-top:0}button,input,select{font:inherit;padding:.55rem .75rem;margin:.25rem;border:1px solid #ccd3df;border-radius:7px}
button{cursor:pointer;background:#2459d3;color:white;border:0}button.secondary{background:#52627b}
.row{display:flex;flex-wrap:wrap;align-items:center;gap:.4rem}.muted{color:#5f6d82}pre{white-space:pre-wrap;overflow-wrap:anywhere}
#message{min-height:1.5rem;color:#a32e2e}label{display:inline-flex;align-items:center;gap:.3rem}
</style>
<header><h1>DCM 播放机管理</h1><p class="muted">设备托管管理页。令牌只保存在当前浏览器中。</p>
<label>Bearer 令牌 <input id="token" type="password" autocomplete="off"></label>
<button id="connect">连接</button><button id="forget" class="secondary">清除令牌</button></header>
<p id="message" role="status"></p>
<section><h2>状态监控</h2><button id="refresh" class="secondary">刷新状态</button><pre id="status">尚未连接</pre></section>
<section><h2>播放控制</h2><div class="row">
<select id="playlist"></select><button id="switch">切换节目</button>
<button id="reload" class="secondary">更新播放列表</button>
<button id="insert" class="secondary">立即插播 Catalogue…</button>
<button id="restore" class="secondary">恢复默认</button></div></section>
<section><h2>播放器设置</h2><label>音量 <input id="volume" type="number" min="0" max="100" value="100"></label>
<button id="saveVolume">设置音量</button></section>
<section><h2>素材管理</h2><div class="row"><select id="category">
<option value="images">图片</option><option value="video">视频</option><option value="web">网页</option>
<option value="text">文本</option><option value="catalogues">Catalogue</option><option value="playlists">播放列表</option></select>
<input id="file" type="file"><button id="upload">上传素材</button>
<button id="validate" class="secondary">校验播放列表…</button>
<button id="cleanup" class="secondary">删除过期日历内容</button>
<button id="sync" class="secondary">同步 CMS 素材</button></div></section>
<section><h2>Catalogue / 播放列表 / 日历</h2>
<p class="muted">通过 JSON 接口创建或更新内容。Catalogue 的分区数必须与每个 Product 的 Zone 数量一致。</p>
<div class="row"><select id="authoring">
<option value="/api/catalogues">保存 Catalogue</option>
<option value="/api/playlists">保存播放列表</option>
<option value="/api/schedules/month">保存月日历</option>
<option value="/api/settings">更新播放器与 dcm.dat 设置</option></select>
<button id="saveJson">提交 JSON</button></div>
<textarea id="payload" rows="10" style="box-sizing:border-box;width:100%;font:14px monospace"></textarea>
</section>
<section><h2>远程诊断</h2><div class="row">
<button id="screenshot" class="secondary">截屏</button>
<button id="logs" class="secondary">下载日志</button>
<button id="restart">重启播放机</button></div></section>
<section><h2>设备能力</h2><button id="capabilities" class="secondary">查看已支持及不可用项目</button><pre id="capabilityList"></pre></section>
<script>
const $=id=>document.getElementById(id), token=$('token'), message=$('message');
token.value=localStorage.getItem('dcm-management-token')||'';
async function api(url,method='GET',body){
 const headers={'Authorization':'Bearer '+token.value};
 if(body!==undefined) headers['Content-Type']='application/json';
 const response=await fetch(url,{method,headers,body:body===undefined?undefined:JSON.stringify(body)});
 if(!response.ok){let detail;try{detail=await response.json()}catch{};throw Error(detail?.message||response.status+' '+response.statusText)}
 return response;
}
async function json(url,method,body){return (await api(url,method,body)).json()}
function report(error){message.textContent=error.message;setTimeout(()=>message.textContent='',7000)}
async function refresh(){
 const data=await json('/api/status');$('status').textContent=JSON.stringify(data,null,2);
 $('volume').value=data.playing.volume;
 const lists=await json('/api/playlists');const select=$('playlist'), current=select.value;
 select.replaceChildren(...lists.map(name=>new Option(name,name)));if(lists.includes(current))select.value=current;
}
$('connect').onclick=async()=>{try{localStorage.setItem('dcm-management-token',token.value);await refresh();message.textContent='已连接'}catch(e){report(e)}};
$('forget').onclick=()=>{localStorage.removeItem('dcm-management-token');token.value='';$('status').textContent='令牌已清除'};
const examples={
 '/api/catalogues':{name:'Sample',layout:{name:'Full',width:1920,height:1080,zones:[{left:0,top:0,width:1920,height:1080}]},products:[{name:'Default',zones:[{type:1,file:'sample.mp4'}]}]},
 '/api/playlists':{name:'SamplePlaylist',items:[{catalogue:'Sample',playTimes:1}]},
 '/api/schedules/month':{month:new Date().toISOString().slice(0,7).replace('-',''),channel:'',days:[{day:1,event:'SamplePlaylist'}]},
 '/api/settings':{player:{volume:60},dcm:{'Global Setting.MultiMonitor':1}}
};
$('authoring').onchange=()=>{$('payload').value=JSON.stringify(examples[$('authoring').value],null,2)};
$('authoring').dispatchEvent(new Event('change'));
$('refresh').onclick=()=>refresh().catch(report);
$('switch').onclick=()=>json('/api/playlists/current','PUT',{name:$('playlist').value}).then(refresh).catch(report);
$('reload').onclick=()=>json('/api/playback/reload','POST',{}).then(refresh).catch(report);
$('insert').onclick=()=>{const name=prompt('Catalogue 名称');if(name)json('/api/playback/insert','POST',{name}).then(refresh).catch(report)};
$('restore').onclick=()=>json('/api/playback/restore','POST',{}).then(refresh).catch(report);
$('saveVolume').onclick=()=>json('/api/settings','PATCH',{player:{volume:Number($('volume').value)}}).then(refresh).catch(report);
$('upload').onclick=async()=>{try{const file=$('file').files[0];if(!file)throw Error('请选择文件');
const url='/api/content/upload?category='+encodeURIComponent($('category').value)+'&name='+encodeURIComponent(file.name);
const response=await fetch(url,{method:'POST',headers:{'Authorization':'Bearer '+token.value,'Content-Type':'application/octet-stream'},body:file});
if(!response.ok){const e=await response.json();throw Error(e.message||response.statusText)}message.textContent='素材上传成功'}catch(e){report(e)}};
$('validate').onclick=()=>{const name=prompt('播放列表名称');if(name)json('/api/content/validate','POST',{kind:'playlist',name}).then(v=>message.textContent=v.valid?'校验通过':'校验未通过').catch(report)};
$('cleanup').onclick=()=>api('/api/content/expired','DELETE').then(r=>r.json()).then(v=>message.textContent=JSON.stringify(v.results)).catch(report);
$('sync').onclick=()=>json('/api/content/sync','POST',{}).catch(report);
$('saveJson').onclick=()=>{try{const data=JSON.parse($('payload').value);json($('authoring').value,$('authoring').value==='/api/settings'?'PATCH':'POST',data).then(v=>message.textContent=JSON.stringify(v)).catch(report)}catch(e){report(e)}};
$('capabilities').onclick=()=>json('/api/capabilities').then(v=>$('capabilityList').textContent=JSON.stringify(v,null,2)).catch(report);
$('screenshot').onclick=async()=>{try{const r=await api('/api/diagnostics/screenshot');const a=document.createElement('a');a.href=URL.createObjectURL(await r.blob());a.download='screenshot.png';a.click();URL.revokeObjectURL(a.href)}catch(e){report(e)}};
$('logs').onclick=async()=>{try{const r=await api('/api/diagnostics/logs');const a=document.createElement('a');a.href=URL.createObjectURL(await r.blob());a.download='player.log';a.click();URL.revokeObjectURL(a.href)}catch(e){report(e)}};
$('restart').onclick=()=>{if(confirm('确定要重启播放机？'))json('/api/diagnostics/restart','POST',{}).then(()=>message.textContent='重启已请求').catch(report)};
</script></html>
''';
}
