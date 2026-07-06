import 'dart:collection';

import 'package:dcm/backend/constants.dart';
import 'package:dcm/backend/models/dcm_global.dart';
import 'package:dcm/backend/utils/log_utils.dart';
import 'package:dcm/backend/utils/string_utils.dart';
import 'package:dcm/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebviewDesktopPlayer extends StatefulWidget {
  final String? url;
  final String? htmlContent;

  const WebviewDesktopPlayer({super.key, this.url, this.htmlContent});

  @override
  State<WebviewDesktopPlayer> createState() => _WebviewDesktopPlayerState();
}

class _WebviewDesktopPlayerState extends State<WebviewDesktopPlayer> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      disableContextMenu: true,
      verticalScrollBarEnabled: hasFlag(DCMGlobal.ieSetting, 0x0001),
      horizontalScrollBarEnabled: hasFlag(DCMGlobal.ieSetting, 0x0002),
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;

  String url = "";
  double progress = 0;

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isUrlorFile = isBlank(widget.htmlContent) &&
        isNotBlank(widget.url); // Utils.isURL(widget.url!);
    //bool isUrl = isNotBlank(widget.url) && Utils.isURL(widget.url!);
    return InAppWebView(
      key: webViewKey,
      webViewEnvironment: webViewEnvironment,
      initialUrlRequest:
          isUrlorFile ? URLRequest(url: WebUri(widget.url!)) : null,
      // initialUrlRequest:
      // URLRequest(url: WebUri(Uri.base.toString().replaceFirst("/#/", "/") + 'page.html')),
      //initialFile: (isUrlorFile && !isUrl) ? widget.url : null,
      initialData: !isUrlorFile
          ? InAppWebViewInitialData(data: widget.htmlContent!)
          : null,
      initialUserScripts: UnmodifiableListView<UserScript>([]),
      initialSettings: settings,
      pullToRefreshController: pullToRefreshController,
      onWebViewCreated: (controller) async {
        webViewController = controller;
      },
      onLoadStart: (controller, url) async {
        logD(
            'onLoadStart: ${url.toString()}; DCMGlobal.ieSetting=${DCMGlobal.ieSetting}');
        this.url = url.toString();
      },
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT);
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        var uri = navigationAction.request.url!;

        if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
            .contains(uri.scheme)) {
          if (await canLaunchUrl(uri)) {
            // Launch the App
            await launchUrl(
              uri,
            );
            // and cancel the request
            return NavigationActionPolicy.CANCEL;
          }
        }

        return NavigationActionPolicy.ALLOW;
      },
      onLoadStop: (controller, url) async {
        if (DCMGlobal.ieSetting == 0x0000) {
          await controller.evaluateJavascript(
              source: "document.querySelector('body').style.overflow='hidden'");
        }
        pullToRefreshController?.endRefreshing();
        this.url = url.toString();
      },
      onReceivedError: (controller, request, error) {
        pullToRefreshController?.endRefreshing();
      },
      onProgressChanged: (controller, progress) {
        if (progress == 100) {
          pullToRefreshController?.endRefreshing();
        }
        this.progress = progress / 100;
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        this.url = url.toString();
      },
      onConsoleMessage: (controller, consoleMessage) {
        logD('onConsoleMessage: $consoleMessage');
      },
    );
  }
}
