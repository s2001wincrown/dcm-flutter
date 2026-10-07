Future<void> preloadContentListThenPlay({
  required Future<void> Function(void Function() onFirstContentPreloaded)
      preload,
  required bool Function() shouldPlay,
  required Future<void> Function() play,
  required void Function() onPlaybackStarted,
  required void Function() onPlaybackFinished,
  required void Function() onPlaybackSkipped,
}) async {
  Future<void>? playback;
  var playbackStarted = false;

  void startPlayback() {
    if (playbackStarted || !shouldPlay()) return;

    playbackStarted = true;
    playback = Future<void>.sync(play);
    onPlaybackStarted();
  }

  try {
    await preload(startPlayback);
  } catch (error, stackTrace) {
    if (playbackStarted) {
      await playback;
      onPlaybackFinished();
    }
    Error.throwWithStackTrace(error, stackTrace);
  }

  if (!playbackStarted) {
    if (shouldPlay()) {
      startPlayback();
    } else {
      onPlaybackSkipped();
      return;
    }
  }

  if (playbackStarted) {
    await playback;
    onPlaybackFinished();
  }
}
