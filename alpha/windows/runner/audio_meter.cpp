#include "audio_meter.h"

using Microsoft::WRL::ComPtr;

float AudioMeter::Peak() {
  if (!meter_ && !Attach()) return -1.0f;
  float peak = 0.0f;
  if (FAILED(meter_->GetPeakValue(&peak))) {
    // Device switched or session ended: look it up again shortly.
    meter_.Reset();
    return -1.0f;
  }
  return peak;
}

bool AudioMeter::Attach() {
  const ULONGLONG now = GetTickCount64();
  if (now < next_lookup_) return false;
  next_lookup_ = now + 1500;

  ComPtr<IMMDeviceEnumerator> enumerator;
  if (FAILED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                              CLSCTX_ALL, IID_PPV_ARGS(&enumerator)))) {
    return false;
  }
  ComPtr<IMMDevice> device;
  if (FAILED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device))) {
    return false;
  }
  ComPtr<IAudioSessionManager2> manager;
  if (FAILED(device->Activate(__uuidof(IAudioSessionManager2), CLSCTX_ALL,
                              nullptr, &manager))) {
    return false;
  }
  ComPtr<IAudioSessionEnumerator> sessions;
  if (FAILED(manager->GetSessionEnumerator(&sessions))) return false;
  int count = 0;
  sessions->GetCount(&count);
  const DWORD self = GetCurrentProcessId();
  for (int i = 0; i < count; i++) {
    ComPtr<IAudioSessionControl> control;
    if (FAILED(sessions->GetSession(i, &control))) continue;
    ComPtr<IAudioSessionControl2> control2;
    if (FAILED(control.As(&control2))) continue;
    DWORD pid = 0;
    control2->GetProcessId(&pid);
    if (pid != self) continue;
    ComPtr<IAudioMeterInformation> meter;
    if (SUCCEEDED(control.As(&meter))) {
      meter_ = meter;
      return true;
    }
  }
  return false;
}
