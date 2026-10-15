#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <functiondiscoverykeys_devpkey.h>
#include <wrl/client.h>
#include <cmath>
#include <stdexcept>
#include <string>
#include "microphone_control.h"

namespace {
using Microsoft::WRL::ComPtr;
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
void Check(HRESULT hr) {
  if (FAILED(hr)) throw std::runtime_error("Windows microphone unavailable (HRESULT " + std::to_string(static_cast<unsigned long>(hr)) + ")");
}
struct ComScope {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  ComScope() { if (hr != RPC_E_CHANGED_MODE) Check(hr); }
  ~ComScope() { if (SUCCEEDED(hr)) CoUninitialize(); }
};
std::string Utf8(const wchar_t* text) {
  const int length = static_cast<int>(wcslen(text));
  const int count = WideCharToMultiByte(CP_UTF8, 0, text, length, nullptr, 0, nullptr, nullptr);
  std::string result(count, '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, length, result.data(), count, nullptr, nullptr);
  return result;
}
std::wstring Utf16(const std::string& text) {
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (!count && !text.empty()) throw std::runtime_error("Invalid microphone ID");
  std::wstring result(count, L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), count);
  return result;
}
M Describe(IMMDevice* device) {
  LPWSTR id = nullptr;
  Check(device->GetId(&id));
  std::string identifier = Utf8(id);
  CoTaskMemFree(id);
  ComPtr<IPropertyStore> properties;
  Check(device->OpenPropertyStore(STGM_READ, &properties));
  PROPVARIANT name;
  PropVariantInit(&name);
  Check(properties->GetValue(PKEY_Device_FriendlyName, &name));
  const std::string label = name.vt == VT_LPWSTR ? Utf8(name.pwszVal) : identifier;
  PropVariantClear(&name);
  return {{V("id"), V(identifier)}, {V("name"), V(label)}};
}
M State(IMMDevice* device, IAudioEndpointVolume* volume) {
  M result = Describe(device);
  BOOL muted = FALSE;
  float gain = 0;
  Check(volume->GetMute(&muted));
  Check(volume->GetMasterVolumeLevelScalar(&gain));
  float peak = 0;
  ComPtr<IAudioMeterInformation> meter;
  if (SUCCEEDED(device->Activate(__uuidof(IAudioMeterInformation), CLSCTX_ALL, nullptr, &meter))) meter->GetPeakValue(&peak);
  result[V("muted")] = V(muted != FALSE);
  result[V("volume")] = V(static_cast<double>(gain));
  result[V("level")] = V(muted ? 0.0 : static_cast<double>(peak));
  return result;
}
}

bool HandleSystemMicrophone(const flutter::MethodCall<V>& call,
    const std::unique_ptr<flutter::MethodResult<V>>& reply) {
  const auto& method = call.method_name();
  if (method != "systemMicrophoneDevices" && method != "systemMicrophoneState" &&
      method != "setSystemMicrophoneMute" && method != "setSystemMicrophoneVolume") return false;
  ComScope com;
  ComPtr<IMMDeviceEnumerator> enumerator;
  Check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL, IID_PPV_ARGS(&enumerator)));
  if (method == "systemMicrophoneDevices") {
    ComPtr<IMMDeviceCollection> devices;
    Check(enumerator->EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE, &devices));
    UINT count = 0;
    Check(devices->GetCount(&count));
    flutter::EncodableList list;
    for (UINT index = 0; index < count; index++) {
      ComPtr<IMMDevice> device;
      if (SUCCEEDED(devices->Item(index, &device))) list.emplace_back(Describe(device.Get()));
    }
    reply->Success(V(list));
    return true;
  }
  const auto* args = call.arguments() ? std::get_if<M>(call.arguments()) : nullptr;
  if (!args) throw std::runtime_error("Expected microphone arguments");
  const auto id = args->find(V("id"));
  if (id == args->end() || !std::holds_alternative<std::string>(id->second)) throw std::runtime_error("Expected microphone ID");
  const auto& identifier = std::get<std::string>(id->second);
  ComPtr<IMMDevice> device;
  if (identifier.empty()) Check(enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &device));
  else Check(enumerator->GetDevice(Utf16(identifier).c_str(), &device));
  ComPtr<IMMEndpoint> endpoint;
  Check(device.As(&endpoint));
  EDataFlow flow;
  Check(endpoint->GetDataFlow(&flow));
  if (flow != eCapture) throw std::runtime_error("Selected device is not a microphone");
  DWORD state = 0;
  Check(device->GetState(&state));
  if (state != DEVICE_STATE_ACTIVE) throw std::runtime_error("Microphone disconnected");
  ComPtr<IAudioEndpointVolume> volume;
  Check(device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr, &volume));
  if (method == "setSystemMicrophoneMute") {
    const auto muted = args->find(V("muted"));
    if (muted == args->end() || !std::holds_alternative<bool>(muted->second)) throw std::runtime_error("Expected mute state");
    Check(volume->SetMute(std::get<bool>(muted->second), nullptr));
  } else if (method == "setSystemMicrophoneVolume") {
    const auto gain = args->find(V("volume"));
    if (gain == args->end() || !std::holds_alternative<double>(gain->second)) throw std::runtime_error("Expected volume scalar");
    const double scalar = std::get<double>(gain->second);
    if (!std::isfinite(scalar) || scalar < 0 || scalar > 1) throw std::runtime_error("Microphone volume must be between 0 and 1");
    Check(volume->SetMasterVolumeLevelScalar(static_cast<float>(scalar), nullptr));
  }
  reply->Success(V(State(device.Get(), volume.Get())));
  return true;
}
