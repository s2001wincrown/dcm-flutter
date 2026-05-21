import 'package:dcm/backend/app.dart';
import 'package:dcm/backend/library_helper.dart';

void loadPlaylists(Function callback) async {
  if (App().playlistLoaded) return;
  App().playlists.clear();
  App().playlists.addAll(await LibraryHelper.loadPlaylists());
  App().playlistLoaded = true;
  callback();
}
