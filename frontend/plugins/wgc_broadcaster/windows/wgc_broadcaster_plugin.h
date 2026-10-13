#ifndef FLUTTER_PLUGIN_WGC_BROADCASTER_PLUGIN_H_
#define FLUTTER_PLUGIN_WGC_BROADCASTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace wgc_broadcaster {
class UnityCaptureSender;

class WgcBroadcasterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  explicit WgcBroadcasterPlugin(flutter::PluginRegistrarWindows *registrar);
  virtual ~WgcBroadcasterPlugin();

  // Disallow copy and assign.
  WgcBroadcasterPlugin(const WgcBroadcasterPlugin&) = delete;
  WgcBroadcasterPlugin& operator=(const WgcBroadcasterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  flutter::PluginRegistrarWindows* registrar_;
  bool is_broadcasting_{false};
  std::unique_ptr<UnityCaptureSender> sender_;
};

}  // namespace wgc_broadcaster

#endif  // FLUTTER_PLUGIN_WGC_BROADCASTER_PLUGIN_H_
