#include "wgc_broadcaster_plugin.h"
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstring>
#include <vector>

namespace wgc_broadcaster {
namespace {
constexpr DWORD kMaxImageSize = 3840 * 2160 * 4 * sizeof(short);
bool IsCameraInstalled() {
  HKEY key = nullptr;
  // UnityCapture's first device, matching the unsuffixed shared-memory names.
  const auto status = RegOpenKeyExW(HKEY_CLASSES_ROOT,
      L"CLSID\\{5C2CD55C-92AD-4999-8666-912BD3E70010}\\InprocServer32",
      0, KEY_READ | KEY_WOW64_64KEY, &key);
  if (status == ERROR_SUCCESS) RegCloseKey(key);
  return status == ERROR_SUCCESS;
}
}  // namespace

// Wire layout is compatible with schellingb/UnityCapture's shared.inl.
class UnityCaptureSender {
 public:
  ~UnityCaptureSender() { Close(); }
  bool Open() {
    if (buffer_) return true;
    mutex_ = CreateMutexA(nullptr, FALSE, "UnityCapture_Mutx");
    want_ = CreateEventA(nullptr, FALSE, FALSE, "UnityCapture_Want");
    sent_ = CreateEventA(nullptr, FALSE, FALSE, "UnityCapture_Sent");
    mapping_ = CreateFileMappingA(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0,
        sizeof(Header) + kMaxImageSize, "UnityCapture_Data");
    if (!mutex_ || !want_ || !sent_ || !mapping_) { Close(); return false; }
    buffer_ = static_cast<Header*>(MapViewOfFile(mapping_, FILE_MAP_WRITE, 0, 0, 0));
    if (!buffer_) { Close(); return false; }
    if (!Lock()) { Close(); return false; }
    buffer_->max_size = kMaxImageSize;
    buffer_->width = 0;
    ReleaseMutex(mutex_);
    return true;
  }
  bool Send(int width, int height, const std::vector<uint8_t>& rgba, bool* consumed) {
    if (!buffer_) return false;
    // A busy receiver drops this frame rather than stalling the Flutter UI or
    // terminating the stream; the next tick sends the newest composition.
    if (!Lock()) { *consumed = false; return true; }
    const size_t size = static_cast<size_t>(width) * height * 4;
    if (size > buffer_->max_size || rgba.size() != size) {
      ReleaseMutex(mutex_);
      return false;
    }
    buffer_->width = width;
    buffer_->height = height;
    buffer_->stride = width;  // UnityCapture measures stride in pixels, not bytes.
    buffer_->format = 0;  // uint8 RGBA
    buffer_->resize_mode = 1;
    buffer_->mirror_mode = 0;
    buffer_->timeout = 1000;
    // Flutter provides top-down rows; UnityCapture's DirectShow DIB is bottom-up.
    const size_t row_size = static_cast<size_t>(width) * 4;
    for (int row = 0; row < height; ++row) {
      std::memcpy(buffer_->data + static_cast<size_t>(row) * row_size,
          rgba.data() + static_cast<size_t>(height - row - 1) * row_size, row_size);
    }
    ReleaseMutex(mutex_);
    SetEvent(sent_);
    *consumed = WaitForSingleObject(want_, 0) == WAIT_OBJECT_0;
    return true;
  }
  void Close() {
    if (buffer_) {
      if (Lock()) { buffer_->width = 0; ReleaseMutex(mutex_); }
      UnmapViewOfFile(buffer_);
      buffer_ = nullptr;
    }
    for (HANDLE* handle : {&mapping_, &want_, &sent_, &mutex_}) {
      if (*handle) { CloseHandle(*handle); *handle = nullptr; }
    }
  }
 private:
  bool Lock() {
    const DWORD status = WaitForSingleObject(mutex_, 5);
    return status == WAIT_OBJECT_0 || status == WAIT_ABANDONED;
  }
  struct Header {
    DWORD max_size;
    int width, height, stride, format, resize_mode, mirror_mode, timeout;
    uint8_t data[1];
  };
  HANDLE mutex_{nullptr}, want_{nullptr}, sent_{nullptr}, mapping_{nullptr};
  Header* buffer_{nullptr};
};

void WgcBroadcasterPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "wgc_broadcaster", &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<WgcBroadcasterPlugin>(registrar);
  channel->SetMethodCallHandler([pointer = plugin.get()](const auto& call, auto result) {
    pointer->HandleMethodCall(call, std::move(result));
  });
  registrar->AddPlugin(std::move(plugin));
}
WgcBroadcasterPlugin::WgcBroadcasterPlugin(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}
WgcBroadcasterPlugin::~WgcBroadcasterPlugin() = default;

void WgcBroadcasterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  using flutter::EncodableValue;
  const auto& method = call.method_name();
  if (method == "startBroadcast") {
    if (!IsCameraInstalled()) {
      result->Error("camera_not_installed", "UnityCapture chưa được đăng ký. Chạy Install.bat rồi mở lại ứng dụng.");
      return;
    }
    if (!sender_) sender_ = std::make_unique<UnityCaptureSender>();
    if (!sender_->Open()) {
      sender_.reset();
      result->Error("sender_unavailable", "Không mở được bộ nhớ chia sẻ UnityCapture.");
      return;
    }
    is_broadcasting_ = true;
    result->Success(EncodableValue(true));
  } else if (method == "sendFrame") {
    const auto* args = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    if (!args) { result->Error("invalid_frame", "Expected a frame map."); return; }
    const auto w = args->find(EncodableValue("width"));
    const auto h = args->find(EncodableValue("height"));
    const auto data = args->find(EncodableValue("rgba"));
    const auto* width = w == args->end() ? nullptr : std::get_if<int32_t>(&w->second);
    const auto* height = h == args->end() ? nullptr : std::get_if<int32_t>(&h->second);
    const auto* rgba = data == args->end() ? nullptr : std::get_if<std::vector<uint8_t>>(&data->second);
    if (!width || !height || !rgba || *width <= 0 || *height <= 0 ||
        *width > 3840 || *height > 2160 || *width % 4 != 0 ||
        rgba->size() != static_cast<size_t>(*width) * *height * 4) {
      result->Error("invalid_frame", "Expected tightly packed RGBA, at most 3840x2160, width divisible by four.");
      return;
    }
    if (!is_broadcasting_ || !sender_) {
      result->Error("not_broadcasting", "Start virtual camera before sending frames.");
      return;
    }
    bool consumed = false;
    if (!sender_->Send(*width, *height, *rgba, &consumed)) {
      result->Error("frame_send_failed", "UnityCapture frame buffer is unavailable or busy.");
      return;
    }
    result->Success(EncodableValue(consumed));
  } else if (method == "stopBroadcast") {
    is_broadcasting_ = false;
    sender_.reset();
    result->Success(EncodableValue(true));
  } else if (method == "isBroadcasting") {
    result->Success(EncodableValue(is_broadcasting_));
  } else if (method == "getPlatformVersion") {
    result->Success(EncodableValue("Windows"));
  } else {
    result->NotImplemented();
  }
}
}  // namespace wgc_broadcaster
