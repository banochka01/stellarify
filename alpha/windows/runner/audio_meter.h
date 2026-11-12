#ifndef RUNNER_AUDIO_METER_H_
#define RUNNER_AUDIO_METER_H_

#include <audiopolicy.h>
#include <endpointvolume.h>
#include <mmdeviceapi.h>
#include <windows.h>
#include <wrl/client.h>

// Peak level of what this process is playing right now, read from the
// Windows audio session meter. No capture, no extra audio path: the system
// already keeps this number for the volume mixer.
class AudioMeter {
 public:
  // 0..1, or a negative value when the session is not found yet.
  float Peak();

 private:
  bool Attach();

  Microsoft::WRL::ComPtr<IAudioMeterInformation> meter_;
  ULONGLONG next_lookup_ = 0;
};

#endif  // RUNNER_AUDIO_METER_H_
