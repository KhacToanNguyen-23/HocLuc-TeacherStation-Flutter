#include "wgc_broadcaster_plugin.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <thread>
#include <atomic>
#include <vector>
#include <chrono>
#include <cstdint>
#include <cstring>
#include <algorithm>

namespace wgc_broadcaster {

#define MAX_SHARED_IMAGE_SIZE (3840 * 2160 * 4 * sizeof(short)) // 4K max buffer

class UnityCaptureSender {
 public:
  explicit UnityCaptureSender(int cap_num = 0) : cap_num_(cap_num) {}
  ~UnityCaptureSender() { Close(); }

  bool Open() {
    if (shared_buf_) return true;

    char num_char = (cap_num_ ? static_cast<char>('0' + cap_num_) : '\0');
    char name_mutex[] = "UnityCapture_Mutx0"; name_mutex[sizeof(name_mutex) - 2] = num_char;
    char name_want[]  = "UnityCapture_Want0"; name_want[sizeof(name_want) - 2] = num_char;
    char name_sent[]  = "UnityCapture_Sent0"; name_sent[sizeof(name_sent) - 2] = num_char;
    char name_data[]  = "UnityCapture_Data0"; name_data[sizeof(name_data) - 2] = num_char;

    h_mutex_ = CreateMutexA(NULL, FALSE, name_mutex);
    if (!h_mutex_) return false;

    WaitForSingleObject(h_mutex_, INFINITE);

    h_want_event_ = CreateEventA(NULL, FALSE, FALSE, name_want);
    h_sent_event_ = CreateEventA(NULL, FALSE, FALSE, name_sent);

    h_shared_file_ = CreateFileMappingA(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0,
                                        sizeof(SharedMemHeader) + MAX_SHARED_IMAGE_SIZE, name_data);
    if (!h_shared_file_) {
      ReleaseMutex(h_mutex_);
      return false;
    }

    shared_buf_ = reinterpret_cast<SharedMemHeader*>(MapViewOfFile(h_shared_file_, FILE_MAP_WRITE, 0, 0, 0));
    if (!shared_buf_) {
      ReleaseMutex(h_mutex_);
      return false;
    }

    if (shared_buf_->maxSize != MAX_SHARED_IMAGE_SIZE) {
      shared_buf_->maxSize = MAX_SHARED_IMAGE_SIZE;
    }

    ReleaseMutex(h_mutex_);
    return true;
  }

  void Close() {
    if (shared_buf_) { UnmapViewOfFile(shared_buf_); shared_buf_ = nullptr; }
    if (h_shared_file_) { CloseHandle(h_shared_file_); h_shared_file_ = nullptr; }
    if (h_want_event_) { CloseHandle(h_want_event_); h_want_event_ = nullptr; }
    if (h_sent_event_) { CloseHandle(h_sent_event_); h_sent_event_ = nullptr; }
    if (h_mutex_) { CloseHandle(h_mutex_); h_mutex_ = nullptr; }
  }

  bool SendFrame(int width, int height, const uint8_t* rgba_data) {
    if (!Open()) return false;

    DWORD data_size = width * height * 4;
    if (shared_buf_->maxSize < data_size) return false;

    WaitForSingleObject(h_mutex_, INFINITE);
    shared_buf_->width = width;
    shared_buf_->height = height;
    shared_buf_->stride = width * 4;
    shared_buf_->format = 0;       // FORMAT_UINT8 (RGBA 8-bit)
    shared_buf_->resizemode = 1;   // RESIZEMODE_LINEAR
    shared_buf_->mirrormode = 0;   // MIRRORMODE_DISABLED
    shared_buf_->timeout = 1000;
    memcpy(shared_buf_->data, rgba_data, data_size);
    ReleaseMutex(h_mutex_);

    SetEvent(h_sent_event_);
    return true;
  }

 private:
  struct SharedMemHeader {
    DWORD maxSize;
    int width;
    int height;
    int stride;
    int format;
    int resizemode;
    int mirrormode;
    int timeout;
    uint8_t data[1];
  };

  int cap_num_{0};
  HANDLE h_mutex_{nullptr};
  HANDLE h_want_event_{nullptr};
  HANDLE h_sent_event_{nullptr};
  HANDLE h_shared_file_{nullptr};
  SharedMemHeader* shared_buf_{nullptr};
};

void WgcBroadcasterPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "wgc_broadcaster",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<WgcBroadcasterPlugin>(registrar);
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

WgcBroadcasterPlugin::WgcBroadcasterPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {}

WgcBroadcasterPlugin::~WgcBroadcasterPlugin() {
  is_broadcasting_ = false;
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
}

void WgcBroadcasterPlugin::CaptureLoop() {
  HWND hwnd = registrar_->GetView()->GetNativeWindow();
  UnityCaptureSender sender(0);

  HDC hdc_screen = GetDC(NULL);
  HDC hdc_mem = CreateCompatibleDC(hdc_screen);
  ReleaseDC(NULL, hdc_screen);

  int last_width = 0;
  int last_height = 0;
  HBITMAP h_bitmap = nullptr;
  HBITMAP h_old_bitmap = nullptr;
  void* p_bits = nullptr;
  std::vector<uint8_t> rgba_buffer;

  while (is_broadcasting_) {
    auto frame_start = std::chrono::steady_clock::now();

    if (IsWindow(hwnd) && !IsIconic(hwnd)) {
      RECT client_rect;
      GetClientRect(hwnd, &client_rect);
      int width = client_rect.right - client_rect.left;
      int height = client_rect.bottom - client_rect.top;

      if (width % 2 != 0) width--;
      if (height % 2 != 0) height--;

      if (width > 0 && height > 0) {
        if (width != last_width || height != last_height) {
          if (h_bitmap) {
            if (h_old_bitmap) {
              SelectObject(hdc_mem, h_old_bitmap);
            }
            DeleteObject(h_bitmap);
            h_bitmap = nullptr;
          }
          BITMAPINFO bmi = {};
          bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
          bmi.bmiHeader.biWidth = width;
          bmi.bmiHeader.biHeight = -height; // top-down DIB
          bmi.bmiHeader.biPlanes = 1;
          bmi.bmiHeader.biBitCount = 32;
          bmi.bmiHeader.biCompression = BI_RGB;

          h_bitmap = CreateDIBSection(hdc_mem, &bmi, DIB_RGB_COLORS, &p_bits, NULL, 0);
          if (h_bitmap) {
            HGDIOBJ old = SelectObject(hdc_mem, h_bitmap);
            if (!h_old_bitmap && old) {
              h_old_bitmap = static_cast<HBITMAP>(old);
            }
          }
          last_width = width;
          last_height = height;
          rgba_buffer.resize(width * height * 4);
        }

        // PW_RENDERFULLCONTENT (2) renders hardware accelerated contents (Xuyen thau)
        BOOL ok = PrintWindow(hwnd, hdc_mem, 2);
        if (!ok) {
          ok = PrintWindow(hwnd, hdc_mem, 0);
        }

        if (ok && p_bits) {
          const uint8_t* bgra = static_cast<const uint8_t*>(p_bits);
          uint8_t* rgba = rgba_buffer.data();
          int total_pixels = width * height;

          // Convert BGRA to RGBA for UnityCapture
          for (int i = 0; i < total_pixels; ++i) {
            rgba[i * 4 + 0] = bgra[i * 4 + 2]; // R
            rgba[i * 4 + 1] = bgra[i * 4 + 1]; // G
            rgba[i * 4 + 2] = bgra[i * 4 + 0]; // B
            rgba[i * 4 + 3] = 255;             // Alpha
          }

          sender.SendFrame(width, height, rgba);
        }
      }
    }

    // Target 30 FPS (~33ms)
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - frame_start).count();
    if (elapsed < 33) {
      std::this_thread::sleep_for(std::chrono::milliseconds(33 - elapsed));
    }
  }

  if (hdc_mem && h_old_bitmap) {
    SelectObject(hdc_mem, h_old_bitmap);
  }
  if (h_bitmap) DeleteObject(h_bitmap);
  if (hdc_mem) DeleteDC(hdc_mem);
}

void WgcBroadcasterPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("startBroadcast") == 0) {
    if (!is_broadcasting_) {
      if (capture_thread_.joinable()) {
        capture_thread_.join();
      }
      is_broadcasting_ = true;
      capture_thread_ = std::thread(&WgcBroadcasterPlugin::CaptureLoop, this);
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("stopBroadcast") == 0) {
    if (is_broadcasting_) {
      is_broadcasting_ = false;
      if (capture_thread_.joinable()) {
        capture_thread_.join();
      }
    }
    result->Success(flutter::EncodableValue(true));
  } else if (method_call.method_name().compare("isBroadcasting") == 0) {
    result->Success(flutter::EncodableValue(is_broadcasting_.load()));
  } else if (method_call.method_name().compare("getPlatformVersion") == 0) {
    result->Success(flutter::EncodableValue("Windows"));
  } else {
    result->NotImplemented();
  }
}

}  // namespace wgc_broadcaster
