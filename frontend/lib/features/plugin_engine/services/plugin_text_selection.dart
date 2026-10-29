import '../domain/models/plugin_manifest.dart';

/// Permission and contribution gate shared by native PDF selection routing.
abstract final class PluginTextSelection {
  static bool acceptsSnippet(PluginManifest? manifest, String? target) {
    if (manifest == null ||
        target == null ||
        !manifest.permissions.contains('board:read_text')) {
      return false;
    }
    return manifest.contributesTools.any(
      (tool) =>
          tool.action == 'snip_region' &&
          tool.snipTextOnly &&
          (tool.target ?? tool.id) == target,
    );
  }

  /// Analysis controls remain saved, but are irrelevant for raw text tools.
  static bool prefersRawSnippets(PluginManifest? manifest) =>
      manifest?.contributesTools.any(
        (tool) => acceptsSnippet(manifest, tool.target ?? tool.id),
      ) ??
      false;

  static bool accepts(PluginManifest? manifest, String? target) {
    if (manifest == null ||
        target == null ||
        !manifest.permissions.contains('board:read_text')) {
      return false;
    }
    return manifest.contributesTools.any(
      (tool) =>
          tool.action == 'toggle_tool' &&
          tool.textSelectionMode &&
          !tool.pdfTapMode &&
          !tool.capturesBoardInput &&
          (tool.target ?? tool.id) == target,
    );
  }

  /// Ignore paragraph-size selections rather than silently truncating a term.
  static String? term(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return clean.isEmpty || clean.length > 500 ? null : clean;
  }
}
