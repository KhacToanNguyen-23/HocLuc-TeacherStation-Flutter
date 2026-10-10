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

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final ui = json['ui'] as Map<String, dynamic>? ?? {};
    final backend = json['backend'] as Map<String, dynamic>? ?? {};

    return PluginManifest(
      id: json['id'] as String? ?? 'unknown_plugin',
      name: json['name'] as String? ?? 'Plugin',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'utility',
      uiEntry: ui['entry'] as String? ?? 'ui/index.html',
      uiPlacement: ui['placement'] as String? ?? 'drawer_panel',
      uiDefaultWidth: (ui['default_width'] as num?)?.toDouble() ?? 420.0,
      hasSidecar: backend['has_sidecar'] as bool? ?? false,
      backendExecutable: backend['executable'] as String?,
      backendPort: (backend['port'] as num?)?.toInt(),
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
