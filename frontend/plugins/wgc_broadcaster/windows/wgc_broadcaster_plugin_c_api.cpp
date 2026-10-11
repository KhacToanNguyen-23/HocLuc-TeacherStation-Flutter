#include "include/wgc_broadcaster/wgc_broadcaster_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "wgc_broadcaster_plugin.h"

void WgcBroadcasterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  wgc_broadcaster::WgcBroadcasterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
