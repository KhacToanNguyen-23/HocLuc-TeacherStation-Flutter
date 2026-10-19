//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audio_bridge/audio_bridge_plugin_c_api.h>
#include <camera_windows/camera_windows.h>
#include <desktop_drop/desktop_drop_plugin.h>
#include <record_windows/record_windows_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <webview_windows/webview_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioBridgePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioBridgePluginCApi"));
  CameraWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CameraWindows"));
  DesktopDropPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopDropPlugin"));
  RecordWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("RecordWindowsPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  WebviewWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WebviewWindowsPlugin"));
}
