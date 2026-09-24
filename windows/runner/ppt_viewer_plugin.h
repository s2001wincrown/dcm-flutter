#ifndef RUNNER_PPT_VIEWER_PLUGIN_H_
#define RUNNER_PPT_VIEWER_PLUGIN_H_

#include <windows.h>

#include <memory>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

class PptViewerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);
  static void SetHostWindow(HWND host_window);

  PptViewerPlugin();
  ~PptViewerPlugin() override;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  static HWND host_window_;
  HWND viewer_window_ = nullptr;
  HANDLE viewer_process_ = nullptr;
  DWORD viewer_process_id_ = 0;
};

#endif
