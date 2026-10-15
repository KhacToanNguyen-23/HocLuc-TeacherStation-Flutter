#include "include/audio_bridge/audio_bridge_plugin_c_api.h"
#include "microphone_control.h"
#define WIN32_LEAN_AND_MEAN
// clang-format off
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <propkeydef.h>
#include <functiondiscoverykeys_devpkey.h>
#include <ks.h>
#include <ksmedia.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <deque>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>
#include <wrl/client.h>
// clang-format on

namespace {
using Microsoft::WRL::ComPtr;
using V = flutter::EncodableValue;
using M = flutter::EncodableMap;
constexpr UINT kEvent = WM_APP + 173;
std::string narrow(const std::wstring &value) {
  int n = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                              static_cast<int>(value.size()), nullptr, 0,
                              nullptr, nullptr);
  std::string text(n, 0);
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      text.data(), n, nullptr, nullptr);
  return text;
}
std::wstring wide(const std::string &value) {
  int n = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                              static_cast<int>(value.size()), nullptr, 0);
  std::wstring text(n, 0);
  MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      text.data(), n);
  return text;
}
void check(HRESULT result) {
  if (FAILED(result))
    throw std::runtime_error(
        "WASAPI error " + std::to_string(static_cast<unsigned long>(result)));
}
const V &get(const M &args, const char *name) {
  auto it = args.find(V(name));
  if (it == args.end())
    throw std::runtime_error("Missing audio argument");
  return it->second;
}
bool floating(const WAVEFORMATEX *f) {
  return f->wFormatTag == WAVE_FORMAT_IEEE_FLOAT ||
         (f->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
          IsEqualGUID(
              reinterpret_cast<const WAVEFORMATEXTENSIBLE *>(f)->SubFormat,
              KSDATAFORMAT_SUBTYPE_IEEE_FLOAT));
}
float sample(const BYTE *p, const WAVEFORMATEX *f) {
  if (floating(f)) {
    float v;
    std::memcpy(&v, p, 4);
    return std::isfinite(v) ? v : 0;
  }
  if (f->wBitsPerSample == 16) {
    short v;
    std::memcpy(&v, p, 2);
    return v / 32768.f;
  }
  if (f->wBitsPerSample == 32) {
    int v;
    std::memcpy(&v, p, 4);
    return static_cast<float>(v / 2147483648.0);
  }
  if (f->wBitsPerSample == 24) {
    int v = p[0] | (p[1] << 8) | (p[2] << 16);
    if (v & 0x800000)
      v |= ~0xffffff;
    return v / 8388608.f;
  }
  throw std::runtime_error("Unsupported endpoint PCM format");
}
void write(BYTE *p, const WAVEFORMATEX *f, float value) {
  value = std::clamp(value, -1.f, 1.f);
  if (floating(f))
    std::memcpy(p, &value, 4);
  else if (f->wBitsPerSample == 16) {
    short v = static_cast<short>(value * 32767);
    std::memcpy(p, &v, 2);
  } else if (f->wBitsPerSample == 32) {
    int v = static_cast<int>(value * 2147483647.0);
    std::memcpy(p, &v, 4);
  } else if (f->wBitsPerSample == 24) {
    int v = static_cast<int>(value * 8388607);
    p[0] = v & 255;
    p[1] = (v >> 8) & 255;
    p[2] = (v >> 16) & 255;
  } else
    throw std::runtime_error("Unsupported render format");
}
std::vector<float> resample(const std::vector<float> &input, int from, int to) {
  if (input.empty() || from == to)
    return input;
  const size_t length =
      static_cast<size_t>(input.size() * static_cast<double>(to) / from);
  std::vector<float> result(length);
  for (size_t i = 0; i < length; i++) {
    double x = i * static_cast<double>(from) / to;
    size_t j = static_cast<size_t>(x);
    double frac = x - j;
    result[i] =
        static_cast<float>(input[std::min(j, input.size() - 1)] * (1 - frac) +
                           input[std::min(j + 1, input.size() - 1)] * frac);
  }
  return result;
}

class Bridge : public flutter::Plugin {
public:
  explicit Bridge(flutter::PluginRegistrarWindows *registrar)
      : registrar_(registrar),
        window_(registrar->GetView()->GetNativeWindow()) {
    delegate_ = registrar->RegisterTopLevelWindowProcDelegate(
        [this](HWND, UINT msg, WPARAM, LPARAM) -> std::optional<LRESULT> {
          if (msg != kEvent)
            return std::nullopt;
          std::deque<M> events;
          {
            std::lock_guard<std::mutex> guard(event_lock_);
            events.swap(events_);
          }
          if (sink_)
            for (auto &item : events)
              sink_->Success(V(item));
          return 0;
        });
    channel_ = std::make_unique<flutter::MethodChannel<V>>(
        registrar->messenger(), "hocluc/audio",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto &call, auto reply) {
      try {
        if (HandleSystemMicrophone(call, reply)) return;
        M args =
            call.arguments() && std::holds_alternative<M>(*call.arguments())
                ? std::get<M>(*call.arguments())
                : M{};
        if (call.method_name() == "devices") {
          reply->Success(V(devices()));
          return;
        }
        if (call.method_name() == "start") {
          stop();
          muted_ = std::get<bool>(get(args, "muted"));
          english_ = false;
          auto in = std::get<std::string>(get(args, "input")),
               out = std::get<std::string>(get(args, "output"));
          running_ = true;
          worker_ = std::thread([this, in, out] { run(in, out); });
          reply->Success();
          return;
        }
        if (call.method_name() == "stop") {
          stop();
          reply->Success();
          return;
        }
        if (call.method_name() == "mode" || call.method_name() == "mute") {
          std::lock_guard<std::mutex> guard(audio_lock_);
          queue_.clear();
          if (call.method_name() == "mode")
            english_ = std::get<bool>(get(args, "english"));
          else
            muted_ = std::get<bool>(get(args, "muted"));
          auto generation = ++generation_;
          reply->Success(V(static_cast<int64_t>(generation)));
          return;
        }
        if (call.method_name() == "preview") {
          stop();
          const auto &bytes =
              std::get<std::vector<uint8_t>>(get(args, "samples"));
          if (bytes.size() % 4 || bytes.size() > 30 * 24000 * 4)
            throw std::runtime_error("Preview audio limit exceeded");
          std::vector<float> pcm(bytes.size() / 4);
          if (!bytes.empty())
            std::memcpy(pcm.data(), bytes.data(), bytes.size());
          if (std::any_of(pcm.begin(), pcm.end(),
                          [](float v) { return !std::isfinite(v); }))
            throw std::runtime_error("Invalid preview PCM");
          auto output = std::get<std::string>(get(args, "output"));
          muted_ = false;
          running_ = true;
          worker_ = std::thread([this, output, pcm = std::move(pcm)] {
            runPreview(output, pcm);
          });
          reply->Success();
          return;
        }
        if (call.method_name() == "enqueue") {
          const auto &bytes =
              std::get<std::vector<uint8_t>>(get(args, "samples"));
          if (bytes.size() % 4 || bytes.size() > 8 * 24000 * 4)
            throw std::runtime_error("TTS playback limit exceeded");
          std::vector<float> pcm(bytes.size() / 4);
          if (!bytes.empty())
            std::memcpy(pcm.data(), bytes.data(), bytes.size());
          if (std::any_of(pcm.begin(), pcm.end(),
                          [](float v) { return !std::isfinite(v); }))
            throw std::runtime_error("Non-finite TTS PCM");
          pcm = resample(pcm, 24000, render_rate_);
          std::lock_guard<std::mutex> guard(audio_lock_);
          if (running_ && english_ && !muted_) {
            if (queue_.size() + pcm.size() >
                static_cast<size_t>(render_rate_) * 8)
              throw std::runtime_error("Speech backlog exceeded");
            queue_.insert(queue_.end(), pcm.begin(), pcm.end());
          }
          reply->Success();
          return;
        }
        reply->NotImplemented();
      } catch (const std::exception &e) {
        reply->Error("AUDIO_UNAVAILABLE", e.what());
      }
    });
    events_channel_ = std::make_unique<flutter::EventChannel<V>>(
        registrar->messenger(), "hocluc/audio/events",
        &flutter::StandardMethodCodec::GetInstance());
    events_channel_->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<V>>(
            [this](const V *, std::unique_ptr<flutter::EventSink<V>> &&sink) {
              sink_ = std::move(sink);
              return nullptr;
            },
            [this](const V *) {
              sink_.reset();
              return nullptr;
            }));
  }
  ~Bridge() override {
    stop();
    registrar_->UnregisterTopLevelWindowProcDelegate(delegate_);
  }

private:
  flutter::EncodableList devices() {
    flutter::EncodableList result;
    HRESULT apartment = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    ComPtr<IMMDeviceEnumerator> enumerator;
    check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                           IID_PPV_ARGS(&enumerator)));
    for (auto flow : {eCapture, eRender}) {
      ComPtr<IMMDeviceCollection> list;
      check(enumerator->EnumAudioEndpoints(flow, DEVICE_STATE_ACTIVE, &list));
      UINT count = 0;
      list->GetCount(&count);
      for (UINT i = 0; i < count; i++) {
        ComPtr<IMMDevice> device;
        list->Item(i, &device);
        LPWSTR id = nullptr;
        device->GetId(&id);
        ComPtr<IPropertyStore> properties;
        device->OpenPropertyStore(STGM_READ, &properties);
        PROPVARIANT name;
        PropVariantInit(&name);
        properties->GetValue(PKEY_Device_FriendlyName, &name);
        result.push_back(V(
            M{{V("id"), V(narrow(id))},
              {V("name"),
               V(name.vt == VT_LPWSTR ? narrow(name.pwszVal) : "Audio device")},
              {V("input"), V(flow == eCapture)}}));
        CoTaskMemFree(id);
        PropVariantClear(&name);
      }
    }
    if (SUCCEEDED(apartment))
      CoUninitialize();
    return result;
  }
  void emit(M value) {
    std::lock_guard<std::mutex> guard(event_lock_);
    if (events_.size() >= 16) {
      events_.clear();
      value = M{{V("type"), V("error")},
                {V("message"), V("Audio event queue overloaded")}};
    }
    events_.push_back(std::move(value));
    // Flutter view is a child HWND. The registrar delegate receives root-window messages.
    PostMessage(GetAncestor(window_, GA_ROOT), kEvent, 0, 0);
  }
  void stop() {
    running_ = false;
    ++generation_;
    if (worker_.joinable())
      worker_.join();
    {
      std::lock_guard<std::mutex> guard(audio_lock_);
      queue_.clear();
    }
    {
      std::lock_guard<std::mutex> guard(event_lock_);
      events_.clear();
    }
  }
  void runPreview(const std::string &output,
                  const std::vector<float> &samples) {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    WAVEFORMATEX *format = nullptr;
    try {
      ComPtr<IMMDeviceEnumerator> enumerator;
      check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                             IID_PPV_ARGS(&enumerator)));
      ComPtr<IMMDevice> device;
      check(enumerator->GetDevice(wide(output).c_str(), &device));
      ComPtr<IAudioClient> client;
      check(device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                             reinterpret_cast<void **>(client.GetAddressOf())));
      check(client->GetMixFormat(&format));
      auto pcm =
          resample(samples, 24000, static_cast<int>(format->nSamplesPerSec));
      check(client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 1000000, 0, format,
                               nullptr));
      ComPtr<IAudioRenderClient> render;
      check(client->GetService(IID_PPV_ARGS(&render)));
      UINT32 total = 0;
      check(client->GetBufferSize(&total));
      check(client->Start());
      size_t position = 0;
      while (running_) {
        UINT32 padding = 0;
        check(client->GetCurrentPadding(&padding));
        if (position >= pcm.size() && padding == 0)
          break;
        UINT32 count = std::min(total - padding,
                                static_cast<UINT32>(pcm.size() - position));
        if (count) {
          BYTE *buffer = nullptr;
          check(render->GetBuffer(count, &buffer));
          for (UINT32 i = 0; i < count; i++) {
            float value = muted_ ? 0 : pcm[position];
            position++;
            for (WORD c = 0; c < format->nChannels; c++)
              write(buffer + i * format->nBlockAlign +
                        c * (format->wBitsPerSample / 8),
                    format, value);
          }
          check(render->ReleaseBuffer(count, 0));
        }
        Sleep(5);
      }
      client->Stop();
      running_ = false;
      emit(M{{V("type"), V("previewEnded")}});
    } catch (const std::exception &error) {
      running_ = false;
      emit(M{{V("type"), V("error")}, {V("message"), V(error.what())}});
    }
    CoTaskMemFree(format);
    CoUninitialize();
  }
  void run(const std::string &input, const std::string &output) {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    WAVEFORMATEX *capture_format = nullptr, *render_format = nullptr;
    ComPtr<IAudioClient> capture_client, render_client;
    try {
      ComPtr<IMMDeviceEnumerator> enumerator;
      check(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                             IID_PPV_ARGS(&enumerator)));
      ComPtr<IMMDevice> mic, speaker;
      check(enumerator->GetDevice(wide(input).c_str(), &mic));
      check(enumerator->GetDevice(wide(output).c_str(), &speaker));
      check(mic->Activate(
          __uuidof(IAudioClient), CLSCTX_ALL, nullptr,
          reinterpret_cast<void **>(capture_client.GetAddressOf())));
      check(speaker->Activate(
          __uuidof(IAudioClient), CLSCTX_ALL, nullptr,
          reinterpret_cast<void **>(render_client.GetAddressOf())));
      check(capture_client->GetMixFormat(&capture_format));
      check(render_client->GetMixFormat(&render_format));
      if (capture_format->wBitsPerSample != 16 &&
          capture_format->wBitsPerSample != 24 &&
          capture_format->wBitsPerSample != 32)
        throw std::runtime_error("Unsupported microphone format");
      if (render_format->wBitsPerSample != 16 &&
          render_format->wBitsPerSample != 24 &&
          render_format->wBitsPerSample != 32)
        throw std::runtime_error("Unsupported playback format");
      render_rate_ = static_cast<int>(render_format->nSamplesPerSec);
      check(capture_client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 1000000, 0,
                                       capture_format, nullptr));
      check(render_client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 1000000, 0,
                                      render_format, nullptr));
      ComPtr<IAudioCaptureClient> capture;
      ComPtr<IAudioRenderClient> render;
      check(capture_client->GetService(IID_PPV_ARGS(&capture)));
      check(render_client->GetService(IID_PPV_ARGS(&render)));
      UINT32 buffer_frames = 0;
      check(render_client->GetBufferSize(&buffer_frames));
      check(capture_client->Start());
      check(render_client->Start());
      emit(M{{V("type"), V("ready")}});
      std::vector<float> frame;
      uint64_t frame_generation = generation_;
      auto level_time = GetTickCount64();
      while (running_) {
        if (generation_ != frame_generation || muted_) {
          frame.clear();
          frame_generation = generation_;
        }
        UINT32 available = 0;
        check(capture->GetNextPacketSize(&available));
        while (available) {
          BYTE *bytes = nullptr;
          UINT32 count = 0;
          DWORD flags = 0;
          check(capture->GetBuffer(&bytes, &count, &flags, nullptr, nullptr));
          std::vector<float> mono(count, 0);
          int stride = capture_format->wBitsPerSample / 8;
          if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT))
            for (UINT32 i = 0; i < count; i++)
              for (WORD c = 0; c < capture_format->nChannels; c++)
                mono[i] +=
                    sample(bytes + i * capture_format->nBlockAlign + c * stride,
                           capture_format) /
                    capture_format->nChannels;
          check(capture->ReleaseBuffer(count));
          if (!muted_) {
            if (english_) {
              auto converted = resample(
                  mono, static_cast<int>(capture_format->nSamplesPerSec),
                  16000);
              frame.insert(frame.end(), converted.begin(), converted.end());
              if (frame.size() >= 1600) {
                std::vector<uint8_t> payload(frame.size() * 4);
                std::memcpy(payload.data(), frame.data(), payload.size());
                emit(M{{V("type"), V("pcm")},
                       {V("generation"),
                        V(static_cast<int64_t>(frame_generation))},
                       {V("samples"), V(payload)}});
                frame.clear();
              }
            } else {
              auto converted = resample(
                  mono, static_cast<int>(capture_format->nSamplesPerSec),
                  render_rate_);
              std::lock_guard<std::mutex> guard(audio_lock_);
              if (!english_ && !muted_ && queue_.size() < static_cast<size_t>(render_rate_) / 2)
                queue_.insert(queue_.end(), converted.begin(), converted.end());
            }
          }
          if (GetTickCount64() - level_time >= 150) {
            float peak = 0;
            for (float x : mono)
              peak = std::max(peak, std::abs(x));
            emit(M{{V("type"), V("level")},
                   {V("value"), V(muted_ ? 0.0 : static_cast<double>(peak))}});
            level_time = GetTickCount64();
          }
          check(capture->GetNextPacketSize(&available));
        }
        UINT32 padding = 0;
        check(render_client->GetCurrentPadding(&padding));
        UINT32 free = buffer_frames - padding;
        if (free) {
          BYTE *bytes = nullptr;
          check(render->GetBuffer(free, &bytes));
          int stride = render_format->wBitsPerSample / 8;
          {
            std::lock_guard<std::mutex> guard(audio_lock_);
            for (UINT32 i = 0; i < free; i++) {
              float value = 0;
              if (!muted_ && !queue_.empty()) {
                value = queue_.front();
                queue_.pop_front();
              }
              for (WORD c = 0; c < render_format->nChannels; c++)
                write(bytes + i * render_format->nBlockAlign + c * stride,
                      render_format, value);
            }
          }
          check(render->ReleaseBuffer(free, 0));
        }
        Sleep(5);
      }
    } catch (const std::exception &e) {
      running_ = false;
      emit(M{{V("type"), V("error")}, {V("message"), V(e.what())}});
    }
    if (capture_client)
      capture_client->Stop();
    if (render_client)
      render_client->Stop();
    CoTaskMemFree(capture_format);
    CoTaskMemFree(render_format);
    CoUninitialize();
  }
  flutter::PluginRegistrarWindows *registrar_;
  HWND window_;
  int delegate_ = 0;
  std::unique_ptr<flutter::MethodChannel<V>> channel_;
  std::unique_ptr<flutter::EventChannel<V>> events_channel_;
  std::unique_ptr<flutter::EventSink<V>> sink_;
  std::thread worker_;
  std::atomic<bool> running_{false}, muted_{false}, english_{false};
  int render_rate_ = 48000;
  std::atomic<uint64_t> generation_{0};
  std::mutex audio_lock_, event_lock_;
  std::deque<float> queue_;
  std::deque<M> events_;
};
} // namespace
void AudioBridgePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto *owner = flutter::PluginRegistrarManager::GetInstance()
                    ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  owner->AddPlugin(std::make_unique<Bridge>(owner));
}
