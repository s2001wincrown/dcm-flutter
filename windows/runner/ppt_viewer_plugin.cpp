#include "ppt_viewer_plugin.h"

#include <windows.h>

#include <chrono>
#include <string>
#include <thread>

namespace {

std::wstring WideFromUtf8(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(
      CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
  if (length <= 0) {
    return {};
  }
  std::wstring result(length, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), length);
  return result;
}

HWND FindMainWindow(DWORD process_id) {
  struct SearchContext {
    DWORD process_id;
    HWND window = nullptr;
  } context{process_id};

  EnumWindows(
      [](HWND window, LPARAM parameter) -> BOOL {
        auto* context = reinterpret_cast<SearchContext*>(parameter);
        DWORD window_process_id = 0;
        GetWindowThreadProcessId(window, &window_process_id);
        if (window_process_id == context->process_id &&
            GetWindow(window, GW_OWNER) == nullptr && IsWindowVisible(window)) {
          context->window = window;
          return FALSE;
        }
        return TRUE;
      },
      reinterpret_cast<LPARAM>(&context));

  return context.window;
}

}  // namespace

HWND PptViewerPlugin::host_window_ = nullptr;

void PptViewerPlugin::RegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  static auto registrar_windows =
      std::make_unique<flutter::PluginRegistrarWindows>(registrar);
  auto plugin = std::make_unique<PptViewerPlugin>();
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar_windows->messenger(), "dcm/ppt_viewer",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar_windows->AddPlugin(std::move(plugin));
}

void PptViewerPlugin::SetHostWindow(HWND host_window) {
  host_window_ = host_window;
}

PptViewerPlugin::PptViewerPlugin() = default;

PptViewerPlugin::~PptViewerPlugin() {
  if (viewer_window_ && IsWindow(viewer_window_)) {
    SetParent(viewer_window_, nullptr);
    ShowWindow(viewer_window_, SW_HIDE);
  }
  if (viewer_process_) {
    TerminateProcess(viewer_process_, 0);
    CloseHandle(viewer_process_);
  }
}

void PptViewerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "start") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("invalid_arguments", "Expected a map of arguments.");
      return;
    }

    const auto viewer_path = arguments->find(flutter::EncodableValue("viewerPath"));
    const auto file_path = arguments->find(flutter::EncodableValue("filePath"));
    if (viewer_path == arguments->end() || file_path == arguments->end()) {
      result->Error("invalid_arguments", "Missing viewerPath or filePath.");
      return;
    }

    const auto* viewer_path_value = std::get_if<std::string>(&viewer_path->second);
    const auto* file_path_value = std::get_if<std::string>(&file_path->second);
    if (!viewer_path_value || !file_path_value || !host_window_) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    if (viewer_process_) {
      result->Success(flutter::EncodableValue(true));
      return;
    }

    const std::wstring viewer = WideFromUtf8(*viewer_path_value);
    const std::wstring file = WideFromUtf8(*file_path_value);
    std::wstring command_line = L"\"" + viewer + L"\" /S \"" + file + L"\"";
    std::wstring mutable_command_line = command_line;

    STARTUPINFOW startup_info{};
    startup_info.cb = sizeof(startup_info);
    PROCESS_INFORMATION process_info{};
    if (!CreateProcessW(viewer.c_str(), mutable_command_line.data(), nullptr,
                        nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr,
                        &startup_info, &process_info)) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    CloseHandle(process_info.hThread);
    viewer_process_ = process_info.hProcess;
    viewer_process_id_ = process_info.dwProcessId;

    for (int attempt = 0; attempt < 50 && !viewer_window_; ++attempt) {
      viewer_window_ = FindMainWindow(viewer_process_id_);
      if (!viewer_window_) {
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
      }
    }

    if (!viewer_window_) {
      TerminateProcess(viewer_process_, 0);
      CloseHandle(viewer_process_);
      viewer_process_ = nullptr;
      viewer_process_id_ = 0;
      result->Success(flutter::EncodableValue(false));
      return;
    }

    const LONG style = GetWindowLongW(viewer_window_, GWL_STYLE);
    SetWindowLongW(viewer_window_, GWL_STYLE,
                   (style | WS_CHILD) & ~(WS_CAPTION | WS_THICKFRAME |
                                           WS_MINIMIZEBOX | WS_MAXIMIZEBOX |
                                           WS_SYSMENU));
    SetParent(viewer_window_, host_window_);
    ShowWindow(viewer_window_, SW_SHOW);
    SetWindowPos(viewer_window_, HWND_TOP, 0, 0, 1, 1,
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (call.method_name() == "resize") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!arguments || !viewer_window_ || !IsWindow(viewer_window_)) {
      result->Success();
      return;
    }

    auto get_int = [arguments](const char* key) -> int {
      const auto item = arguments->find(flutter::EncodableValue(key));
      if (item == arguments->end()) {
        return 0;
      }
      if (const auto* value = std::get_if<int32_t>(&item->second)) {
        return *value;
      }
      return 0;
    };
    SetWindowPos(viewer_window_, HWND_TOP, get_int("left"), get_int("top"),
                 get_int("width"), get_int("height"),
                 SWP_NOACTIVATE | SWP_SHOWWINDOW);
    result->Success();
    return;
  }

  if (call.method_name() == "stop") {
    if (viewer_window_ && IsWindow(viewer_window_)) {
      SetParent(viewer_window_, nullptr);
      ShowWindow(viewer_window_, SW_HIDE);
    }
    viewer_window_ = nullptr;
    if (viewer_process_) {
      TerminateProcess(viewer_process_, 0);
      CloseHandle(viewer_process_);
      viewer_process_ = nullptr;
    }
    viewer_process_id_ = 0;
    result->Success();
    return;
  }

  result->NotImplemented();
}
