import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'package:dcm/backend/library_helper.dart';

final _trackNotifiers = Expando<ValueNotifier<String?>>();
final _rateNotifiers = Expando<ValueNotifier<double>>();
final _constDoubleNotifiers = Expando<ValueNotifier<double>>();
final _constBoolNotifiers = Expando<ValueNotifier<bool>>();

extension PlayerCommandExtensions on Player {
  Future<void> command(List<String> args) async {
    if (args.isEmpty) {
      return;
    }

    final command = args[0].toLowerCase();
    switch (command) {
      case 'show-text':
      case 'script-binding':
      case 'sub-remove':
      case 'sub-add':
      case 'keypress':
        return;
      case 'loadfile':
        if (args.length < 2) {
          return;
        }
        final uri = LibraryHelper.normalizeMediaSource(args[1]);
        final media = Media(uri);
        final append = args.length >= 3 && args[2] == 'append';
        if (append) {
          await add(media);
        } else {
          await open(media, play: true);
        }
        return;
      case 'stop':
        await stop();
        return;
      case 'pause':
        await pause();
        return;
      case 'cycle':
        if (args.length >= 2 && args[1] == 'pause') {
          await playOrPause();
        }
        return;
      case 'playlist-remove':
        if (args.length >= 2) {
          final index = int.tryParse(args[1]);
          if (index != null) {
            await remove(index);
          }
        }
        return;
      case 'playlist-shuffle':
        await setShuffle(true);
        return;
      case 'playlist-unshuffle':
        await setShuffle(false);
        return;
      case 'playlist-prev':
        await previous();
        return;
      case 'playlist-next':
        await next();
        return;
      case 'seek':
        if (args.length >= 2) {
          final seconds = int.tryParse(args[1]);
          if (seconds != null) {
            await seek(Duration(seconds: seconds));
          }
        }
        return;
      default:
        debugPrint('Player.command: unsupported command ${args.join(' ')}');
    }
  }

  ValueNotifier<String?> get vid {
    return _trackNotifier((track) => track.video.id);
  }

  ValueNotifier<String?> get aid {
    return _trackNotifier((track) => track.audio.id);
  }

  ValueNotifier<String?> get sid {
    return _trackNotifier((track) => track.subtitle.id);
  }

  ValueNotifier<double> get speed {
    var notifier = _rateNotifiers[this];
    if (notifier == null) {
      notifier = ValueNotifier<double>(state.rate);
      _rateNotifiers[this] = notifier;
      stream.rate.listen((value) {
        notifier?.value = value;
      });
    }
    return notifier;
  }

  ValueNotifier<double> get audioDelay {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<double> get brightness {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<double> get contrast {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<double> get saturation {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<double> get gamma {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<double> get hue {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<bool> get subVisibility {
    return _constBool(this, true);
  }

  ValueNotifier<double> get subDelay {
    return _constDouble(this, 0.0);
  }

  ValueNotifier<String?> get secondarySid {
    return sid;
  }

  Future<void> setProperty(String name, String value) async {
    switch (name) {
      case 'vid':
        await setVideoTrack(VideoTrack(value, null, null));
        return;
      case 'aid':
        await setAudioTrack(AudioTrack(value, null, null));
        return;
      case 'sid':
        await setSubtitleTrack(SubtitleTrack(value, null, null));
        return;
      case 'speed':
        final rate = double.tryParse(value);
        if (rate != null) {
          await setRate(rate);
        }
        return;
      case 'audio-delay':
      case 'brightness':
      case 'contrast':
      case 'saturation':
      case 'gamma':
      case 'hue':
      case 'sub-visibility':
      case 'sub-delay':
        return;
      default:
        debugPrint('Player.setProperty: unsupported property $name=$value');
    }
  }

  Future<String> getProperty(String name) async {
    try {
      if (platform == null) {
        return 'unknown';
      }
      final dynamic nativePlatform = platform;
      final result = await nativePlatform.getProperty(name);
      if (result is String && result.isNotEmpty) {
        return result;
      }
      if (result != null) {
        return result.toString();
      }
    } catch (error, stackTrace) {
      debugPrint('Player.getProperty: unsupported property $name - $error');
      debugPrint(stackTrace.toString());
    }
    return 'unknown';
  }

  ValueNotifier<String?> _trackNotifier(String Function(Track) selector) {
    var notifier = _trackNotifiers[this];
    if (notifier == null) {
      notifier = ValueNotifier<String?>(selector(state.track));
      _trackNotifiers[this] = notifier;
      stream.track.listen((track) {
        notifier?.value = selector(track);
      });
    }
    return notifier;
  }

  ValueNotifier<double> _constDouble(Player player, double value) {
    var notifier = _constDoubleNotifiers[player];
    if (notifier == null) {
      notifier = ValueNotifier<double>(value);
      _constDoubleNotifiers[player] = notifier;
    }
    return notifier;
  }

  ValueNotifier<bool> _constBool(Player player, bool value) {
    var notifier = _constBoolNotifiers[player];
    if (notifier == null) {
      notifier = ValueNotifier<bool>(value);
      _constBoolNotifiers[player] = notifier;
    }
    return notifier;
  }
}
