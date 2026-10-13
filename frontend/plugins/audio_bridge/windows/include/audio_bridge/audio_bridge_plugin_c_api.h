#ifndef AUDIO_BRIDGE_C_API_H
#define AUDIO_BRIDGE_C_API_H
#include <flutter_plugin_registrar.h>
#ifdef FLUTTER_PLUGIN_IMPL
#define AUDIO_EXPORT __declspec(dllexport)
#else
#define AUDIO_EXPORT __declspec(dllimport)
#endif
#ifdef __cplusplus
extern "C" {
#endif
AUDIO_EXPORT void AudioBridgePluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);
#ifdef __cplusplus
}
#endif
#endif
