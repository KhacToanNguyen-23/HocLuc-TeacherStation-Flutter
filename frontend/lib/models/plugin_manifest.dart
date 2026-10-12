class PluginBackend {
  const PluginBackend({
    this.type = 'python',
    this.entry,
    this.port,
    this.healthEndpoint,
  });

  final String type;
  final String? entry;
  final int? port;
  final String? healthEndpoint;

  factory PluginBackend.fromJson(Map<String, dynamic> json) {
    return PluginBackend(
      type: json['type'] as String? ?? 'python',
      entry: json['entry'] as String? ?? json['executable'] as String?,
      port: (json['port'] as num?)?.toInt(),
      healthEndpoint: json['health_endpoint'] as String?,
    );
  }
}

class PluginManifest {
  PluginManifest({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.author = 'Unknown',
    this.description = '',
    this.category = 'utility',
    this.uiEntry = 'ui/index.html',
    this.uiPlacement = 'drawer_panel',
    this.uiDefaultWidth = 420.0,
    this.hasSidecar = false,
    this.backendExecutable,
    this.backendPort,
    this.backend,
  });

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String category;
  final String uiEntry;
  final String uiPlacement;
  final double uiDefaultWidth;
  final bool hasSidecar;
  final String? backendExecutable;
  final int? backendPort;
  final PluginBackend? backend;

  double get defaultWidth => uiDefaultWidth;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final ui = json['ui'] as Map<String, dynamic>? ?? {};
    final backendMap = json['backend'] as Map<String, dynamic>? ?? {};

    final uiEntry =
        json['main'] as String? ?? ui['entry'] as String? ?? 'ui/index.html';
    final uiPlacement =
        json['placement'] as String? ??
        ui['placement'] as String? ??
        'drawer_panel';
    final uiDefaultWidth =
        (json['default_width'] as num?)?.toDouble() ??
        (ui['default_width'] as num?)?.toDouble() ??
        420.0;

    final backendObj = json['backend'] is Map
        ? PluginBackend.fromJson(json['backend'] as Map<String, dynamic>)
        : null;

    final backendExecutable =
        backendObj?.entry ?? backendMap['executable'] as String?;
    final backendPort =
        backendObj?.port ?? (backendMap['port'] as num?)?.toInt();
    final hasSidecar =
        backendObj != null || (backendMap['has_sidecar'] as bool? ?? false);

    return PluginManifest(
      id: json['id'] as String? ?? 'unknown_plugin',
      name: json['name'] as String? ?? 'Plugin',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'utility',
      uiEntry: uiEntry,
      uiPlacement: uiPlacement,
      uiDefaultWidth: uiDefaultWidth,
      hasSidecar: hasSidecar,
      backendExecutable: backendExecutable,
      backendPort: backendPort,
      backend: backendObj,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'category': category,
    'ui': {
      'entry': uiEntry,
      'placement': uiPlacement,
      'default_width': uiDefaultWidth,
    },
    'backend': {
      'has_sidecar': hasSidecar,
      'executable': backendExecutable,
      'port': backendPort,
    },
  };
}
