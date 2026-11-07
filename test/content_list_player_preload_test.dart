import 'dart:async';

import 'package:dcm/backend/services/content_list_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts playback as soon as the first content is preloaded', () async {
    final remainingPreloadCompleter = Completer<void>();
    final playbackCompleter = Completer<void>();
    final playbackStartedCompleter = Completer<void>();
    final operations = <String>[];
    var shouldPlay = true;

    final playback = preloadContentListThenPlay(
      preload: (onFirstContentPreloaded) async {
        operations.add('preload');
        onFirstContentPreloaded();
        operations.add('remaining preload');
        await remainingPreloadCompleter.future;
      },
      shouldPlay: () => shouldPlay,
      play: () async {
        operations.add('play started');
        await playbackCompleter.future;
        operations.add('play finished');
      },
      onPlaybackStarted: () {
        operations.add('rebuild started');
        playbackStartedCompleter.complete();
      },
      onPlaybackFinished: () => operations.add('rebuild finished'),
      onPlaybackSkipped: () => operations.add('play skipped'),
    );

    await playbackStartedCompleter.future;
    expect(
      operations,
      [
        'preload',
        'play started',
        'rebuild started',
        'remaining preload',
      ],
    );

    remainingPreloadCompleter.complete();
    playbackCompleter.complete();
    await playback;

    expect(
      operations,
      [
        'preload',
        'play started',
        'rebuild started',
        'remaining preload',
        'play finished',
        'rebuild finished',
      ],
    );

    shouldPlay = false;
    await preloadContentListThenPlay(
      preload: (onFirstContentPreloaded) async {},
      shouldPlay: () => shouldPlay,
      play: () async => operations.add('unexpected play'),
      onPlaybackStarted: () => operations.add('unexpected start rebuild'),
      onPlaybackFinished: () => operations.add('unexpected finish rebuild'),
      onPlaybackSkipped: () => operations.add('play skipped'),
    );

    expect(
      operations,
      [
        'preload',
        'play started',
        'rebuild started',
        'remaining preload',
        'play finished',
        'rebuild finished',
        'play skipped',
      ],
    );
  });

  test('does not play when preload fails', () async {
    final operations = <String>[];

    await expectLater(
      preloadContentListThenPlay(
        preload: (onFirstContentPreloaded) async {
          operations.add('preload');
          throw StateError('preload failed');
        },
        shouldPlay: () => true,
        play: () async => operations.add('play'),
        onPlaybackStarted: () => operations.add('started'),
        onPlaybackFinished: () => operations.add('finished'),
        onPlaybackSkipped: () => operations.add('skipped'),
      ),
      throwsA(isA<StateError>()),
    );

    expect(operations, ['preload']);
  });
}
