import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'plugin_storage_manager.dart';

/// Lightweight, internal loopback HTTP server that serves plugin web assets.
/// Resolves CORS/Same-Origin restrictions on Chromium WebView2 (file:/// scheme)
/// allowing modern React/Vite/Vue SPA packages (ES modules, Web Workers, WASM) to run cleanly,
/// and automatically injects the HocLuc Host Bridge SDK (`/__hocluc_sdk__/hocluc-plugin-sdk.js`)
/// for open-source web apps when `inject_sdk: true`.
class PluginWebServer {
  static final PluginWebServer _instance = PluginWebServer._internal();
  factory PluginWebServer() => _instance;
  PluginWebServer._internal();

  static PluginWebServer get instance => _instance;

  static const String _kEmbeddedSdkJs = '''
(function (root, factory) {
  if (typeof define === 'function' && define.amd) {
    define([], factory);
  } else if (typeof module === 'object' && module.exports) {
    module.exports = factory();
  } else {
    root.HocLuc = root.HocLuc || factory();
  }
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';
  const pendingRequests = new Map();
  let requestCounter = 0;
  function generateRequestId() {
    return 'req_' + Date.now() + '_' + ++requestCounter;
  }
  function isHostAvailable() {
    return (
      typeof window !== 'undefined' &&
      window.chrome &&
      window.chrome.webview &&
      typeof window.chrome.webview.postMessage === 'function'
    );
  }
  function sendRpc(action, payload) {
    return new Promise((resolve, reject) => {
      const id = generateRequestId();
      const message = { id, action, payload: payload || {} };
      pendingRequests.set(id, { resolve, reject });
      setTimeout(() => {
        if (pendingRequests.has(id)) {
          pendingRequests.delete(id);
          reject(new Error("[HocLucSDK] Timeout waiting for host action '" + action + "'"));
        }
      }, 8000);
      if (isHostAvailable()) {
        try {
          window.chrome.webview.postMessage(JSON.stringify(message));
        } catch (err) {
          pendingRequests.delete(id);
          reject(err);
        }
      } else {
        setTimeout(() => {
          handleHostResponse({ id, success: true, data: null });
        }, 50);
      }
    });
  }
  function handleHostResponse(response) {
    if (!response || !response.id) return;
    const pending = pendingRequests.get(response.id);
    if (!pending) return;
    pendingRequests.delete(response.id);
    if (response.success) {
      pending.resolve(response.data);
    } else {
      pending.reject(new Error(response.error || 'Unknown host error'));
    }
  }
  if (typeof window !== 'undefined') {
    window.__hocluc_handle_response = handleHostResponse;
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.addEventListener('message', function (event) {
        try {
          const data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
          handleHostResponse(data);
        } catch (e) {}
      });
    }
  }
  return {
    version: '2.1.0',
    getContext: function () { return sendRpc('context:get', {}); },
    board: {
      getSelectedText: function () { return sendRpc('board:get_selected_text', {}); },
      insertAnnotation: function (annotation) { return sendRpc('board:insert_annotation', annotation); },
      clearAnnotations: function () { return sendRpc('board:clear_annotations', {}); }
    },
    storage: {
      get: function (key) { return sendRpc('storage:get', { key }); },
      set: function (key, value) { return sendRpc('storage:set', { key, value }); }
    }
  };
});
''';

  HttpServer? _server;
  int? get port => _server?.port;
  bool get isRunning => _server != null;

  /// Start the loopback HTTP server on an ephemeral OS-assigned port.
  Future<int> start() async {
    if (_server != null) return _server!.port;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint(
        '[PluginWebServer] Serving plugins at http://127.0.0.1:${_server!.port}/',
      );

      _server!.listen(
        _handleRequest,
        onError: (err) => debugPrint('[PluginWebServer] Error: $err'),
      );

      return _server!.port;
    } catch (e) {
      debugPrint('[PluginWebServer] Failed to bind local server: $e');
      rethrow;
    }
  }

  /// Resolve full HTTP URL for a plugin asset.
  String? getUrl(String pluginId, String relativePath) {
    if (_server == null) return null;
    final cleanPath = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    return 'http://127.0.0.1:${_server!.port}/plugins/$pluginId/$cleanPath';
  }

  /// Stop and release local server resources.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      debugPrint('[PluginWebServer] Stopped local server.');
    }
  }

  String? _lastServedPluginId;

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Enable local CORS headers
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    try {
      final segments = request.uri.pathSegments;

      // Serve built-in Host Bridge SDK for open-source auto-injection
      if (segments.length >= 2 &&
          segments[0] == '__hocluc_sdk__' &&
          segments[1] == 'hocluc-plugin-sdk.js') {
        response.headers.contentType = ContentType(
          'application',
          'javascript',
          charset: 'utf-8',
        );
        response.write(_kEmbeddedSdkJs);
        await response.close();
        return;
      }

      // Expected pattern: /plugins/<plugin_id>/<relative_path...>
      if (segments.length >= 2 && segments[0] == 'plugins') {
        final pluginId = segments[1];
        _lastServedPluginId = pluginId;
        final relPath = segments.sublist(2).join('/');
        if (relPath.contains('..')) {
          response.statusCode = HttpStatus.forbidden;
          await response.close();
          return;
        }

        final installedDir = PluginStorageManager.instance
            .getInstalledDirectory(pluginId);

        if (installedDir != null) {
          final targetFile = File('${installedDir.path}/$relPath');

          if (targetFile.existsSync()) {
            await _servePluginFile(response, targetFile, installedDir);
            return;
          }
        }
      } else if (segments.isNotEmpty) {
        // Fallback for Open-Source web apps requesting root-relative paths (e.g. /audio/nk-cream-click-quiet-v6.wav)
        final relPath = segments.join('/');
        if (relPath.contains('..')) {
          response.statusCode = HttpStatus.forbidden;
          await response.close();
          return;
        }

        String? candidatePluginId;
        final referer = request.headers.value(HttpHeaders.refererHeader);
        if (referer != null) {
          final refUri = Uri.tryParse(referer);
          if (refUri != null &&
              refUri.pathSegments.length >= 2 &&
              refUri.pathSegments[0] == 'plugins') {
            candidatePluginId = refUri.pathSegments[1];
          }
        }
        candidatePluginId ??= _lastServedPluginId;

        if (candidatePluginId != null) {
          final installedDir = PluginStorageManager.instance
              .getInstalledDirectory(candidatePluginId);
          if (installedDir != null) {
            final uiFile = File('${installedDir.path}/ui/$relPath');
            if (uiFile.existsSync()) {
              await _servePluginFile(response, uiFile, installedDir);
              return;
            }
            final rootFile = File('${installedDir.path}/$relPath');
            if (rootFile.existsSync()) {
              await _servePluginFile(response, rootFile, installedDir);
              return;
            }
          }
        }
      }

      response.statusCode = HttpStatus.notFound;
      response.write('Not found: ${request.uri.path}');
      await response.close();
    } catch (e) {
      debugPrint('[PluginWebServer] Request error: $e');
      try {
        response.statusCode = HttpStatus.internalServerError;
        await response.close();
      } catch (_) {}
    }
  }

  Future<void> _servePluginFile(
    HttpResponse response,
    File targetFile,
    Directory installedDir,
  ) async {
    _setContentType(response, targetFile.path);
    final lower = targetFile.path.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      final manifest = PluginStorageManager.instance.loadManifestFromDir(
        installedDir,
      );
      var html = await targetFile.readAsString();
      if ((manifest == null || manifest.injectSdk) &&
          !html.contains('hocluc-plugin-sdk.js') &&
          !html.contains('sdk.js')) {
        const sdkTag =
            '<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>';
        if (html.contains('</head>')) {
          html = html.replaceFirst('</head>', '  $sdkTag\n</head>');
        } else if (html.contains('</body>')) {
          html = html.replaceFirst('</body>', '  $sdkTag\n</body>');
        } else {
          html = '$sdkTag\n$html';
        }
      }
      final bytes = utf8.encode(html);
      response.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      return;
    }

    await response.addStream(targetFile.openRead());
    await response.close();
  }

  void _setContentType(HttpResponse response, String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) {
      response.headers.contentType = ContentType(
        'text',
        'html',
        charset: 'utf-8',
      );
    } else if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      response.headers.contentType = ContentType(
        'application',
        'javascript',
        charset: 'utf-8',
      );
    } else if (lower.endsWith('.css')) {
      response.headers.contentType = ContentType(
        'text',
        'css',
        charset: 'utf-8',
      );
    } else if (lower.endsWith('.json')) {
      response.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
    } else if (lower.endsWith('.wasm')) {
      response.headers.contentType = ContentType('application', 'wasm');
    } else if (lower.endsWith('.png')) {
      response.headers.contentType = ContentType('image', 'png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      response.headers.contentType = ContentType('image', 'jpeg');
    } else if (lower.endsWith('.svg')) {
      response.headers.contentType = ContentType('image', 'svg+xml');
    } else if (lower.endsWith('.ico')) {
      response.headers.contentType = ContentType('image', 'x-icon');
    } else if (lower.endsWith('.woff2')) {
      response.headers.contentType = ContentType('font', 'woff2');
    } else if (lower.endsWith('.woff')) {
      response.headers.contentType = ContentType('font', 'woff');
    } else if (lower.endsWith('.ttf')) {
      response.headers.contentType = ContentType('font', 'ttf');
    } else if (lower.endsWith('.wav')) {
      response.headers.contentType = ContentType('audio', 'wav');
    } else if (lower.endsWith('.mp3')) {
      response.headers.contentType = ContentType('audio', 'mpeg');
    } else {
      response.headers.contentType = ContentType.binary;
    }
  }
}
