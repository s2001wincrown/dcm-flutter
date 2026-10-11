#include "ppt_viewer_plugin.h"

#include <windows.h>
#include <tlhelp32.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <string>
#include <thread>
#include <vector>

namespace {

template <typename T>
bool ReadRemote(HANDLE process, uintptr_t address, T* value) {
  SIZE_T bytes_read = 0;
  return ReadProcessMemory(process, reinterpret_cast<LPCVOID>(address), value,
                           sizeof(T), &bytes_read) &&
         bytes_read == sizeof(T);
}

bool ReadRemoteString(HANDLE process, uintptr_t address, std::string* value) {
  value->clear();
  for (size_t index = 0; index < 512; ++index) {
    char character = '\0';
    if (!ReadRemote(process, address + index, &character)) {
      return false;
    }
    if (character == '\0') {
      return true;
    }
    value->push_back(character);
  }
  return false;
}

uintptr_t FindRemoteModule(DWORD process_id, const std::wstring& module_name) {
  HANDLE snapshot =
      CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32,
                               process_id);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return 0;
  }

  MODULEENTRY32W module_entry{};
  module_entry.dwSize = sizeof(module_entry);
  uintptr_t module_base = 0;
  if (Module32FirstW(snapshot, &module_entry)) {
    do {
      if (_wcsicmp(module_entry.szModule, module_name.c_str()) == 0) {
        module_base = reinterpret_cast<uintptr_t>(module_entry.modBaseAddr);
        break;
      }
    } while (Module32NextW(snapshot, &module_entry));
  }
  CloseHandle(snapshot);
  return module_base;
}

uintptr_t ResolveRemoteExport(HANDLE process, DWORD process_id,
                              uintptr_t module_base, const char* export_name,
                              int depth = 0) {
  if (depth > 4) {
    return 0;
  }

  IMAGE_DOS_HEADER dos_header{};
  if (!ReadRemote(process, module_base, &dos_header) ||
      dos_header.e_magic != IMAGE_DOS_SIGNATURE || dos_header.e_lfanew <= 0) {
    return 0;
  }

  const uintptr_t nt_headers =
      module_base + static_cast<uintptr_t>(dos_header.e_lfanew);
  DWORD signature = 0;
  IMAGE_FILE_HEADER file_header{};
  if (!ReadRemote(process, nt_headers, &signature) ||
      signature != IMAGE_NT_SIGNATURE ||
      !ReadRemote(process, nt_headers + sizeof(signature), &file_header)) {
    return 0;
  }

  const uintptr_t optional_header =
      nt_headers + sizeof(signature) + sizeof(file_header);
  WORD optional_magic = 0;
  if (!ReadRemote(process, optional_header, &optional_magic) ||
      (optional_magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC &&
       optional_magic != IMAGE_NT_OPTIONAL_HDR64_MAGIC)) {
    return 0;
  }

  const uintptr_t data_directory_offset =
      optional_magic == IMAGE_NT_OPTIONAL_HDR32_MAGIC
          ? offsetof(IMAGE_OPTIONAL_HEADER32, DataDirectory)
          : offsetof(IMAGE_OPTIONAL_HEADER64, DataDirectory);
  IMAGE_DATA_DIRECTORY export_directory_entry{};
  if (!ReadRemote(
          process,
          optional_header + data_directory_offset +
              IMAGE_DIRECTORY_ENTRY_EXPORT * sizeof(IMAGE_DATA_DIRECTORY),
          &export_directory_entry) ||
      export_directory_entry.VirtualAddress == 0) {
    return 0;
  }

  IMAGE_EXPORT_DIRECTORY export_directory{};
  if (!ReadRemote(process,
                  module_base + export_directory_entry.VirtualAddress,
                  &export_directory)) {
    return 0;
  }

  std::vector<DWORD> name_rvas(export_directory.NumberOfNames);
  std::vector<WORD> ordinals(export_directory.NumberOfNames);
  std::vector<DWORD> function_rvas(export_directory.NumberOfFunctions);
  SIZE_T bytes_read = 0;
  if (name_rvas.empty() || function_rvas.empty() ||
      !ReadProcessMemory(
          process,
          reinterpret_cast<LPCVOID>(module_base +
                                    export_directory.AddressOfNames),
          name_rvas.data(), name_rvas.size() * sizeof(DWORD), &bytes_read) ||
      bytes_read != name_rvas.size() * sizeof(DWORD) ||
      !ReadProcessMemory(
          process,
          reinterpret_cast<LPCVOID>(module_base +
                                    export_directory.AddressOfNameOrdinals),
          ordinals.data(), ordinals.size() * sizeof(WORD), &bytes_read) ||
      bytes_read != ordinals.size() * sizeof(WORD) ||
      !ReadProcessMemory(
          process,
          reinterpret_cast<LPCVOID>(module_base +
                                    export_directory.AddressOfFunctions),
          function_rvas.data(),
          function_rvas.size() * sizeof(DWORD), &bytes_read) ||
      bytes_read != function_rvas.size() * sizeof(DWORD)) {
    return 0;
  }

  for (size_t index = 0; index < name_rvas.size(); ++index) {
    std::string current_name;
    if (!ReadRemoteString(process, module_base + name_rvas[index],
                          &current_name) ||
        current_name != export_name || ordinals[index] >= function_rvas.size()) {
      continue;
    }

    const DWORD function_rva = function_rvas[ordinals[index]];
    const uintptr_t export_start =
        module_base + export_directory_entry.VirtualAddress;
    const uintptr_t export_end =
        export_start + export_directory_entry.Size;
    const uintptr_t function_address = module_base + function_rva;
    if (function_address < export_start || function_address >= export_end) {
      return function_address;
    }

    std::string forwarder;
    if (!ReadRemoteString(process, function_address, &forwarder)) {
      return 0;
    }
    const size_t separator = forwarder.find('.');
    if (separator == std::string::npos) {
      return 0;
    }

    std::string forwarded_module = forwarder.substr(0, separator);
    std::transform(forwarded_module.begin(), forwarded_module.end(),
                   forwarded_module.begin(),
                   [](unsigned char character) {
                     return static_cast<char>(std::tolower(character));
                   });
    std::wstring wide_module(forwarded_module.begin(),
                             forwarded_module.end());
    if (wide_module.find(L'.') == std::wstring::npos) {
      wide_module += L".dll";
    }
    const uintptr_t forwarded_base =
        FindRemoteModule(process_id, wide_module);
    if (forwarded_base == 0) {
      return 0;
    }

    const std::string forwarded_name = forwarder.substr(separator + 1);
    return ResolveRemoteExport(process, process_id, forwarded_base,
                               forwarded_name.c_str(), depth + 1);
  }
  return 0;
}

bool InjectDll(HANDLE process, DWORD process_id,
               const std::wstring& dll_path) {
  const size_t path_size = (dll_path.size() + 1) * sizeof(wchar_t);
  void* remote_path =
      VirtualAllocEx(process, nullptr, path_size, MEM_COMMIT | MEM_RESERVE,
                     PAGE_READWRITE);
  if (!remote_path) {
    return false;
  }

  SIZE_T bytes_written = 0;
  const bool path_written =
      WriteProcessMemory(process, remote_path, dll_path.c_str(), path_size,
                         &bytes_written) &&
      bytes_written == path_size;
  const uintptr_t kernel32 =
      FindRemoteModule(process_id, L"kernel32.dll");
  const uintptr_t load_library =
      kernel32 == 0
          ? 0
          : ResolveRemoteExport(process, process_id, kernel32, "LoadLibraryW");
  if (!path_written || load_library == 0) {
    VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
    return false;
  }

  HANDLE remote_thread = CreateRemoteThread(
      process, nullptr, 0,
      reinterpret_cast<LPTHREAD_START_ROUTINE>(load_library), remote_path, 0,
      nullptr);
  if (!remote_thread) {
    VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
    return false;
  }

  const DWORD wait_result = WaitForSingleObject(remote_thread, 10000);
  DWORD exit_code = 0;
  const bool injected =
      wait_result == WAIT_OBJECT_0 &&
      GetExitCodeThread(remote_thread, &exit_code) && exit_code != 0;
  CloseHandle(remote_thread);
  if (wait_result == WAIT_OBJECT_0) {
    VirtualFreeEx(process, remote_path, 0, MEM_RELEASE);
  }
  return injected;
}

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

    std::array<wchar_t, 32768> application_path{};
    const DWORD application_path_length =
        GetModuleFileNameW(nullptr, application_path.data(),
                           static_cast<DWORD>(application_path.size()));
    if (application_path_length == 0 ||
        application_path_length >= application_path.size()) {
      result->Success(flutter::EncodableValue(false));
      return;
    }
    const std::wstring dll_path =
        (std::filesystem::path(application_path.data()).parent_path() /
         L"AppPPTInject.dll")
            .wstring();
    if (GetFileAttributesW(dll_path.c_str()) == INVALID_FILE_ATTRIBUTES) {
      result->Success(flutter::EncodableValue(false));
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
                        nullptr, FALSE, CREATE_NO_WINDOW | CREATE_SUSPENDED,
                        nullptr, nullptr, &startup_info, &process_info)) {
      result->Success(flutter::EncodableValue(false));
      return;
    }

    if (!InjectDll(process_info.hProcess, process_info.dwProcessId, dll_path) ||
        ResumeThread(process_info.hThread) == static_cast<DWORD>(-1)) {
      TerminateProcess(process_info.hProcess, 0);
      CloseHandle(process_info.hThread);
      CloseHandle(process_info.hProcess);
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
