import 'package:flutter/material.dart';
import 'package:dcm/backend/app.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dcm/backend/constants.dart' as constants;
import 'package:dcm/backend/utils/l10n_utils.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<StatefulWidget> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String libmpvVersion = 'unknown';
  String ffmpegVersion = 'unknown';
  String libassVersion = 'unknown';
  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    var libmpvVer = await App().player.getProperty('mpv-version');
    var ffmpegVer = await App().player.getProperty('ffmpeg-version');
    var libassVer = await App().player.getProperty('libass-version');
    setState(() {
      libmpvVersion = libmpvVer;
      ffmpegVersion = ffmpegVer;
      libassVersion = libassVer;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              '关于'.l10n,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(30)),
            ),
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    constants.appIcon,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // const SizedBox(
                      //   height: 12,
                      // ),
                      Text(
                        constants.appName,
                        style: TextStyle(
                          fontSize: 40,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ' ${constants.version}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(
              '帮助'.l10n,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.info_outline,
            ),
            title: Text('依赖库版本'.l10n),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              App().dialog(
                (context) => AlertDialog(
                  content: SelectableText(
                    'libmpv: $libmpvVersion\n'
                    'ffmpeg: $ffmpegVersion\n'
                    'libass: $libassVersion',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.data_object,
            ),
            title: Text('项目主页'.l10n),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              launchUrl(Uri.https('github.com', '/s2001wincrown/dcm'));
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.feedback_outlined,
            ),
            title: Text('反馈'.l10n),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              launchUrl(
                Uri.https('github.com', '/s2001wincrown/dcm/issues/new'),
              );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.note_outlined,
            ),
            title: Text('许可证'.l10n),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              showLicensePage(context: context);
            },
          ),
        ],
      ),
    );
  }
}
