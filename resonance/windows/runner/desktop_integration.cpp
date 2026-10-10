#include "desktop_integration.h"

#include <objbase.h>
#include <objectarray.h>
#include <propkey.h>
#include <propvarutil.h>
#include <shlobj.h>
#include <shobjidl.h>

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"Resonance";
constexpr const wchar_t kInstanceMutex[] = L"Local\\Resonance.SingleInstance";

HANDLE g_instance_mutex = nullptr;

struct JumpTask {
  const wchar_t* title;
  const wchar_t* arguments;
  int icon_index;
};

IShellLinkW* CreateTaskLink(const wchar_t* exe_path, const JumpTask& task) {
  IShellLinkW* link = nullptr;
  if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&link)))) {
    return nullptr;
  }
  link->SetPath(exe_path);
  link->SetArguments(task.arguments);
  link->SetIconLocation(exe_path, task.icon_index);
  link->SetDescription(task.title);
  IPropertyStore* store = nullptr;
  if (SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&store)))) {
    PROPVARIANT title;
    if (SUCCEEDED(InitPropVariantFromString(task.title, &title))) {
      store->SetValue(PKEY_Title, title);
      store->Commit();
      PropVariantClear(&title);
    }
    store->Release();
  }
  return link;
}

}  // namespace

std::string FindQuickActionArgument(const std::vector<std::string>& arguments) {
  const std::string prefix = "--action=";
  for (const auto& argument : arguments) {
    if (argument.rfind(prefix, 0) == 0) {
      return argument.substr(prefix.size());
    }
  }
  return std::string();
}

bool ForwardToRunningInstance(const std::string& action) {
  g_instance_mutex = ::CreateMutexW(nullptr, TRUE, kInstanceMutex);
  if (g_instance_mutex == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return false;
  }
  HWND existing = nullptr;
  // The first instance may still be starting; give its window a moment.
  for (int attempt = 0; attempt < 20 && existing == nullptr; ++attempt) {
    existing = ::FindWindowW(kWindowClassName, kWindowTitle);
    if (existing == nullptr) ::Sleep(100);
  }
  if (existing == nullptr) {
    return false;
  }
  if (!action.empty()) {
    COPYDATASTRUCT data{};
    data.dwData = kQuickActionCopyDataTag;
    data.cbData = static_cast<DWORD>(action.size());
    data.lpData = const_cast<char*>(action.data());
    DWORD_PTR result = 0;
    ::SendMessageTimeoutW(existing, WM_COPYDATA, 0,
                          reinterpret_cast<LPARAM>(&data), SMTO_ABORTIFHUNG,
                          2000, &result);
  } else {
    if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
    ::ShowWindow(existing, SW_SHOW);
    ::SetForegroundWindow(existing);
  }
  return true;
}

void RegisterJumpListTasks() {
  wchar_t exe_path[MAX_PATH];
  if (::GetModuleFileNameW(nullptr, exe_path, MAX_PATH) == 0) return;

  ICustomDestinationList* list = nullptr;
  if (FAILED(CoCreateInstance(CLSID_DestinationList, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list)))) {
    return;
  }
  UINT min_slots = 0;
  IObjectArray* removed = nullptr;
  if (SUCCEEDED(list->BeginList(&min_slots, IID_PPV_ARGS(&removed)))) {
    IObjectCollection* tasks = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                                   CLSCTX_INPROC_SERVER,
                                   IID_PPV_ARGS(&tasks)))) {
      const JumpTask entries[] = {
          // Escaped so the source stays ASCII for any MSVC code page.
          {L"\u041C\u043E\u044F \u0432\u043E\u043B\u043D\u0430",
           L"--action=wave", 0},
          {L"\u041F\u043E\u0441\u043B\u0435\u0434\u043D\u0438\u0439 "
           L"\u043F\u043B\u0435\u0439\u043B\u0438\u0441\u0442",
           L"--action=lastPlaylist", 0},
          {L"\u041F\u0430\u0443\u0437\u0430", L"--action=pause", 0},
      };
      for (const auto& entry : entries) {
        IShellLinkW* link = CreateTaskLink(exe_path, entry);
        if (link != nullptr) {
          tasks->AddObject(link);
          link->Release();
        }
      }
      IObjectArray* array = nullptr;
      if (SUCCEEDED(tasks->QueryInterface(IID_PPV_ARGS(&array)))) {
        list->AddUserTasks(array);
        array->Release();
      }
      tasks->Release();
    }
    list->CommitList();
    if (removed != nullptr) removed->Release();
  }
  list->Release();
}
