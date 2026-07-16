import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dcm/backend/keymap_helper.dart';
import 'package:dcm/backend/library_helper.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/models/player_global.dart';
import 'package:dcm/backend/models/playitem.dart';
import 'package:dcm/backend/models/playlist_item.dart';
import 'package:dcm/backend/models/settings.dart';
import 'package:dcm/backend/player_command_ext.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/utils.dart';
import 'package:dcm/backend/xml_settings/contenttype_manager.dart';
import 'package:dcm/pages/home.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class App {
  late final String dataPath;
  late final String? uniqueKey;
  late final DateTime dtStartup;

  late AppSettings settings;

  final contentKey = GlobalKey<NavigatorState>();
  void dialog(Widget Function(BuildContext) builder) {
    if (contentKey.currentState != null) {
      KeyMapHelper.keyBindinglock++;
      showDialog(
        useRootNavigator: false,
        context: contentKey.currentState!.context,
        builder: builder,
      ).whenComplete(() {
        KeyMapHelper.keyBindinglock--;
      });
    }
  }

  Map<String, Function> actions = {};

  late final Player player;
  late final VideoController controller;

  bool playlistLoaded = false;
  bool mediaLibraryLoaded = false;
  List<PlaylistItem> playlists = [];
  List<PlayItem> mediaLibrary = [];
  static final App _instance = App._internal();
  factory App() => _instance;
  App._internal() {
    settings = AppSettings();
  }

  Future<void> init() async {
    dtStartup = DateTime.now();
    dataPath = (await getApplicationSupportDirectory()).path;
    initFileLogger(dataPath);
    // Get Device ID
    uniqueKey = await Utils.getUniqueKey();
    //await DCMGlobal.loadFromIni();
    //ContentTypeManager.loadContentTypes();
    await loadAppSetting(uniqueKey);
    if (DCMGlobal.autoContentUpdate) {
      // Ensure globalPlayer is initialized from CMS or local fallback
      await initGlobalPlayer();
    }
    await loadSettings();
    bool needsUpdate = false;
    if (settings.screenshotPath == '') {
      settings.screenshotPath = '$dataPath/screenshots';
      var dir = Directory(settings.screenshotPath);
      if (!await dir.exists()) {
        dir.create();
      }
      needsUpdate = true;
    }
    if (needsUpdate) {
      await saveSettings();
    }
    player = Player(
      configuration: const PlayerConfiguration(
        title: 'dcm',
        osc: false,
        muted: false,
        async: true,
        libass: false,
        logLevel: MPVLogLevel.error,
      ),
    );
    player.stream.playlist.listen(
      (event) {
        if (event.medias.isNotEmpty) {
          var src = event.medias[event.index].uri;
          playingTitle = basenameWithoutExtension(src);
          playingCover = '${withoutExtension(src)}.cover.jpg';
        } else {
          playingTitle = 'Not Playing';
          playingCover = null;
        }
      },
    );
    controller = VideoController(player);
    player.setVolume(settings.volume);
    settings.tempPath = (await getTemporaryDirectory()).path;
  }

  Future<void> loadSettings() async {
    var settingsPath = "$dataPath/config/settings.json";
    var fp = File(settingsPath);
    if (!await fp.exists()) {
      await fp.create(recursive: true);
      var data = AppSettings().toJson();
      var str = jsonEncode(data);
      await fp.writeAsString(str);
    }
    settings = AppSettings.fromJson(jsonDecode(await fp.readAsString()));
  }

  Future<void> saveSettings() async {
    var settingsPath = "$dataPath/config/settings.json";
    var fp = File(settingsPath);
    var data = settings.toJson();
    var str = jsonEncode(data);
    await fp.writeAsString(str);
  }

  void executeAction(String action) {
    actions[action]?.call();
  }

  void updateStatus() {
    HomePage.refresh?.call();
  }

  String? playingCover;
  String playingTitle = 'Not Playing';

  bool loop = false;
  bool showAHMessage = true;
  int? playTimeForDemo; //minutes

  bool seeking = false;
  double seekingPos = 0;

  int voWidth = 0;
  int voHeight = 0;
  void refreshVO() {
    var voInfo = player.state.videoParams;
    int w = voInfo.dw ?? 1, h = voInfo.dh ?? 1;
    double fac = min(voWidth / w, voHeight / h);
    controller.setSize(width: (w * fac) ~/ 1, height: (h * fac) ~/ 1);
    player.command(['show-text', '已更新显示区域']);
  }

  void restoreVO() {
    controller.setSize();
    player.command(['show-text', '已恢复默认显示大小']);
  }

  void openMedia(PlayItem media) {
    if (!settings.rememberStatus) {
      _resetPlayerStatus();
    }
    final video = Media(LibraryHelper.normalizeMediaSource(media.source));
    player.open(video, play: settings.autoPlay);
  }

  void openPlaylist(PlaylistItem playlistItem, bool shuffleList) {
    if (playlistItem.items.isEmpty) {
      return;
    }
    if (!settings.rememberStatus) {
      _resetPlayerStatus();
    }
    if (shuffleList) {
      player.open(LibraryHelper.convertToPlaylist(playlistItem), play: false);
      player.setShuffle(true);
      player.jump(0);
      if (App().settings.autoPlay) player.play();
    } else {
      player.open(
        LibraryHelper.convertToPlaylist(playlistItem),
        play: App().settings.autoPlay,
      );
    }
  }

  void _resetPlayerStatus() {
    player.setVolume(settings.defaultVolume);
    player.setRate(settings.defaultSpeed);
  }
}
