import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'plugin_manager.dart';

/// DTO representing an extension package advertised by the Backend Marketplace Registry.
class PluginCatalogItem {
  const PluginCatalogItem({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    this.author = 'HocLuc Team',
    this.category = 'general',
    this.uiPlacement = 'drawer_panel',
    this.uiDefaultWidth = 380,
    this.uiDefaultHeight = 600,
    this.resizable = false,
    this.frameless = false,
    this.injectSdk = false,
    this.iconUrl = '',
    required this.downloadUrl,
    this.sizeBytes = 0,
    this.sha256 = '',
    this.contributesTools = const [],
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String category;
  final String uiPlacement;
  final double uiDefaultWidth;
  final double uiDefaultHeight;
  final bool resizable;
  final bool frameless;
  final bool injectSdk;
  final String iconUrl;
  final String downloadUrl;
  final int sizeBytes;
  final String sha256;
  final List<PluginToolContribution> contributesTools;

  factory PluginCatalogItem.fromJson(Map<String, dynamic> json) {
    final rawTools = json['contributesTools'];
    final tools = <PluginToolContribution>[];
    if (rawTools is List) {
      for (final item in rawTools) {
        if (item is Map<String, dynamic>) {
          tools.add(PluginToolContribution.fromJson(item));
        } else if (item is Map) {
          tools.add(
            PluginToolContribution.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final placement = json['uiPlacement']?.toString() ?? 'drawer_panel';

    return PluginCatalogItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '1.0.0',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? 'HocLuc Team',
      category: json['category']?.toString() ?? 'general',
      uiPlacement: placement,
      uiDefaultWidth:
          (json['uiDefaultWidth'] as num?)?.toDouble() ??
          (placement == 'floating_window' ? 350 : 420),
      uiDefaultHeight:
          (json['uiDefaultHeight'] as num?)?.toDouble() ??
          (placement == 'floating_window' ? 620 : 600),
      resizable: json['resizable'] == true,
      frameless: json['frameless'] == true,
      injectSdk: json['injectSdk'] == true,
      iconUrl: json['iconUrl']?.toString() ?? '',
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256']?.toString() ?? '',
      contributesTools: tools,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'category': category,
    'uiPlacement': uiPlacement,
    'uiDefaultWidth': uiDefaultWidth,
    'uiDefaultHeight': uiDefaultHeight,
    'resizable': resizable,
    'frameless': frameless,
    'injectSdk': injectSdk,
    'iconUrl': iconUrl,
    'downloadUrl': downloadUrl,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'contributesTools': contributesTools.map((t) => t.toJson()).toList(),
  };

  PluginManifest toManifest() {
    return PluginManifest(
      id: id,
      name: name,
      version: version,
      description: description,
      author: author,
      category: category,
      uiPlacement: uiPlacement,
      uiDefaultWidth: uiDefaultWidth,
      uiDefaultHeight: uiDefaultHeight,
      resizable: resizable,
      frameless: frameless,
      injectSdk: injectSdk,
      contributesTools: contributesTools,
    );
  }
}

/// Service for syncing the Cloud/Backend Plugin Marketplace catalog and downloading `.hlep` packages on demand.
class PluginMarketplaceService {
  PluginMarketplaceService._internal();
  static final PluginMarketplaceService instance =
      PluginMarketplaceService._internal();
  factory PluginMarketplaceService() => instance;

  static const String _kCachedCatalogKey = 'cached_marketplace_catalog_v1';
  static const String _defaultBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  http.Client _httpClient = http.Client();
  String _baseUrl = _defaultBaseUrl;

  String get baseUrl => _baseUrl;

  @visibleForTesting
  void configureForTesting({http.Client? client, String? baseUrl}) {
    if (client != null) _httpClient = client;
    if (baseUrl != null) _baseUrl = baseUrl;
  }

  /// Resolves a relative `/api/marketplace/...` URL against the configured backend base URL.
  String resolveUrl(String pathOrUrl) {
    if (pathOrUrl.isEmpty) return '';
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    final normalizedBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = pathOrUrl.startsWith('/')
        ? pathOrUrl
        : '/$pathOrUrl';
    return '$normalizedBase$normalizedPath';
  }

  /// Fetches the available plugin catalog from Backend (`GET /api/marketplace/plugins`),
  /// caching the response in SharedPreferences for offline fallback.
  Future<List<PluginCatalogItem>> fetchCatalog() async {
    final uri = Uri.parse(resolveUrl('/api/marketplace/plugins'));
    try {
      final response = await _httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final items = decoded
              .whereType<Map>()
              .map(
                (raw) =>
                    PluginCatalogItem.fromJson(Map<String, dynamic>.from(raw)),
              )
              .where((item) => item.id.isNotEmpty)
              .toList();
          await _cacheCatalog(items);
          return items;
        }
      }
    } catch (e) {
      debugPrint(
        '[PluginMarketplaceService] Remote catalog fetch failed ($e), falling back to cache.',
      );
    }
    return loadCachedCatalog();
  }

  /// Loads cached catalog from SharedPreferences when offline.
  Future<List<PluginCatalogItem>> loadCachedCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_kCachedCatalogKey);
      if (rawJson == null || rawJson.isEmpty) return const [];
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (raw) =>
                  PluginCatalogItem.fromJson(Map<String, dynamic>.from(raw)),
            )
            .where((item) => item.id.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[PluginMarketplaceService] Error reading cached catalog: $e');
    }
    return const [];
  }

  Future<void> _cacheCatalog(List<PluginCatalogItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_kCachedCatalogKey, encoded);
    } catch (e) {
      debugPrint('[PluginMarketplaceService] Error caching catalog: $e');
    }
  }

  /// Downloads the raw `.hlep` zip archive bytes for a plugin from the backend marketplace.
  Future<Uint8List> downloadPackageBytes(
    String pluginId, {
    String? customDownloadUrl,
  }) async {
    final path =
        (customDownloadUrl != null && customDownloadUrl.isNotEmpty)
        ? customDownloadUrl
        : '/api/marketplace/plugins/$pluginId/download';
    final uri = Uri.parse(resolveUrl(path));

    final response = await _httpClient
        .get(uri)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpExceptionWithStatus(
        response.statusCode,
        'Không thể tải gói tiện ích "$pluginId" (HTTP ${response.statusCode}).',
      );
    }
    return response.bodyBytes;
  }

  /// Downloads `.hlep` from the backend marketplace and installs it into local disk cache via [PluginManager].
  Future<InstalledPlugin> downloadAndInstall(
    PluginCatalogItem item, {
    PluginManager? manager,
  }) async {
    final bytes = await downloadPackageBytes(
      item.id,
      customDownloadUrl: item.downloadUrl,
    );
    final targetManager = manager ?? PluginManager.instance;
    return targetManager.installPluginFromBytes(bytes, '${item.id}.hlep');
  }
}

class HttpExceptionWithStatus implements Exception {
  const HttpExceptionWithStatus(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'HttpExceptionWithStatus($statusCode): $message';
}


