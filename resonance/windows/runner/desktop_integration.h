#ifndef RUNNER_DESKTOP_INTEGRATION_H_
#define RUNNER_DESKTOP_INTEGRATION_H_

#include <windows.h>

#include <string>
#include <vector>

// WM_COPYDATA tag used to forward a quick action to the running instance.
constexpr ULONG_PTR kQuickActionCopyDataTag = 0x52534E41;  // "RSNA"

// Returns the value of the first "--action=..." argument, or an empty string.
std::string FindQuickActionArgument(const std::vector<std::string>& arguments);

// When another Resonance window is already running, forwards |action| to it,
// brings it to the foreground and returns true (the caller should exit).
bool ForwardToRunningInstance(const std::string& action);

// Registers the taskbar jump-list tasks (wave, last playlist and pause).
// Failures are ignored: the jump list is a convenience.
void RegisterJumpListTasks();

#endif  // RUNNER_DESKTOP_INTEGRATION_H_
