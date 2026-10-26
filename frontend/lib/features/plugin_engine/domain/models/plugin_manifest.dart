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

/// Represents a declarative tool contribution from manifest.json (`contributes.tools`),
/// modeled after VS Code Extension contribution points.
class PluginToolContribution {
  const PluginToolContribution({
    required this.id,
    required this.label,
    this.icon = 'auto_awesome',
    this.tooltip = '',
    this.action = 'toggle_tool',
    this.target,
    this.widgetKey,
    this.pdfTapMode = false,
    this.settingKey,
    this.defaultValue = false,
  });

  final String id;
  final String label;
  final String icon;
  final String tooltip;
  final String action; // 'snip_region' | 'toggle_tool' | 'quick_input' | 'rpc_event'
  final String? target;
  final String? widgetKey;
  /// Declares that this contributed tool owns PDF tap gestures while active.
  final bool pdfTapMode;
  final String? settingKey;
  final bool defaultValue;

  factory PluginToolContribution.fromJson(Map<String, dynamic> json) {
    return PluginToolContribution(
      id: json['id']?.toString() ?? 'tool',
      label: json['label']?.toString() ?? 'Công cụ',
      icon: json['icon']?.toString() ?? 'auto_awesome',
      tooltip: json['tooltip']?.toString() ?? '',
      action: json['action']?.toString() ?? 'toggle_tool',
      target: json['target']?.toString(),
      widgetKey: json['key']?.toString(),
      pdfTapMode: json['pdf_tap_mode'] == true,
      settingKey: json['setting_key']?.toString(),
      defaultValue: json['default_value'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    'tooltip': tooltip,
    'action': action,
    if (target != null) 'target': target,
    if (widgetKey != null) 'key': widgetKey,
    if (pdfTapMode) 'pdf_tap_mode': true,
    if (settingKey != null) 'setting_key': settingKey,
    if (settingKey != null) 'default_value': defaultValue,
  };
}

class PluginManifest {
  PluginManifest({
    required this.id,
    required this.name,
    this.version = '1.0.0',
    this.author = 'Unknown',
    this.description = '',
    this.category = 'utility',
    this.iconPath = 'icon.png',
    this.uiEntry = 'ui/index.html',
    this.uiPlacement = 'drawer_panel',
    this.uiDefaultWidth = 420.0,
    this.uiDefaultHeight = 560.0,
    this.resizable = true,
    this.frameless = false,
    this.movable = true,
    this.injectSdk = true,
    this.hasSidecar = false,
    this.backendExecutable,
    this.backendPort,
    this.backend,
    this.permissions = const [],
    List<PluginToolContribution>? contributesTools,
  }) : contributesTools =
           contributesTools ??
           (uiPlacement == 'floating_window'
               ? const []
               : defaultLessonTools);

  static const List<PluginToolContribution> defaultLessonTools = [
    PluginToolContribution(
      id: 'snip_passage',
      label: 'Quét đoạn văn',
      icon: 'crop_free',
      tooltip:
          'Kéo chụp đoạn văn trên đề để highlight Ngữ pháp & Từ vựng trực tiếp trên file (PrtSc)',
      action: 'snip_region',
      target: 'dgnl',
      widgetKey: 'quick_snip_dgnl_button',
    ),
    PluginToolContribution(
      id: 'svo',
      label: 'Công cụ S-V-O',
      icon: 'auto_awesome',
      tooltip: 'Bật công cụ bóc tách S-V-O',
      action: 'toggle_tool',
      target: 'svo',
      widgetKey: 'svo_tool_button',
    ),
    PluginToolContribution(
      id: 'quick_sentence',
      label: 'Nhập câu',
      icon: 'edit_note',
      tooltip: 'Nhập hoặc chọn câu để phân tích',
      action: 'quick_input',
      widgetKey: 'quick_sentence_button',
    ),
  ];

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String category;
  final String iconPath;
  final String uiEntry;
  final String uiPlacement;
  final double uiDefaultWidth;
  final double uiDefaultHeight;
  final bool resizable;
  final bool frameless;
  final bool movable;
  final bool injectSdk;
  final bool hasSidecar;
  final String? backendExecutable;
  final int? backendPort;
  final PluginBackend? backend;
  final List<String> permissions;
  final List<PluginToolContribution> contributesTools;

  double get defaultWidth => uiDefaultWidth;
  double get defaultHeight => uiDefaultHeight;

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final ui = json['ui'] as Map<String, dynamic>? ?? {};
    final backendMap = json['backend'] as Map<String, dynamic>? ?? {};
    final contributesMap = json['contributes'] as Map<String, dynamic>?;

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
    final uiDefaultHeight =
        (json['default_height'] as num?)?.toDouble() ??
        (ui['default_height'] as num?)?.toDouble() ??
        560.0;
    final resizable =
        json['resizable'] as bool? ?? ui['resizable'] as bool? ?? true;
    final frameless =
        json['frameless'] as bool? ?? ui['frameless'] as bool? ?? false;
    final movable =
        json['movable'] as bool? ?? ui['movable'] as bool? ?? true;
    final injectSdk =
        json['inject_sdk'] as bool? ?? ui['inject_sdk'] as bool? ?? true;
    final iconPath =
        json['icon'] as String? ?? ui['icon'] as String? ?? 'icon.png';

    final backendObj = json['backend'] is Map
        ? PluginBackend.fromJson(json['backend'] as Map<String, dynamic>)
        : null;

    final backendExecutable =
        backendObj?.entry ?? backendMap['executable'] as String?;
    final backendPort =
        backendObj?.port ?? (backendMap['port'] as num?)?.toInt();
    final hasSidecar =
        backendObj != null || (backendMap['has_sidecar'] as bool? ?? false);

    List<PluginToolContribution>? parsedTools;
    if (contributesMap != null && contributesMap['tools'] is List) {
      parsedTools = (contributesMap['tools'] as List)
          .whereType<Map>()
          .map((e) => PluginToolContribution.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return PluginManifest(
      id: json['id'] as String? ?? 'unknown_plugin',
      name: json['name'] as String? ?? 'Plugin',
      version: json['version'] as String? ?? '1.0.0',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'utility',
      iconPath: iconPath,
      uiEntry: uiEntry,
      uiPlacement: uiPlacement,
      uiDefaultWidth: uiDefaultWidth,
      uiDefaultHeight: uiDefaultHeight,
      resizable: resizable,
      frameless: frameless,
      movable: movable,
      injectSdk: injectSdk,
      hasSidecar: hasSidecar,
      backendExecutable: backendExecutable,
      backendPort: backendPort,
      backend: backendObj,
      permissions:
          (json['permissions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      contributesTools: parsedTools,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'category': category,
    'icon': iconPath,
    'frameless': frameless,
    'inject_sdk': injectSdk,
    'permissions': permissions,
    'ui': {
      'entry': uiEntry,
      'placement': uiPlacement,
      'default_width': uiDefaultWidth,
      'default_height': uiDefaultHeight,
      'resizable': resizable,
      'frameless': frameless,
      'movable': movable,
    },
    'contributes': {
      'tools': contributesTools.map((t) => t.toJson()).toList(),
    },
    'backend': {
      'has_sidecar': hasSidecar,
      'executable': backendExecutable,
      'port': backendPort,
    },
  };
}
