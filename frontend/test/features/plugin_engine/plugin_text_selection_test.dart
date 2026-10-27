import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_text_selection.dart';

void main() {
  PluginManifest manifest({
    bool permission = true,
    bool selection = true,
    bool tap = false,
    bool capture = false,
    bool rawSnip = false,
    String action = 'toggle_tool',
  }) => PluginManifest(
    id: 'test.lookup',
    name: 'Lookup',
    permissions: permission ? ['board:read_text'] : [],
    contributesTools: [
      PluginToolContribution(
        id: 'lookup',
        target: 'term',
        label: 'Lookup',
        action: action,
        textSelectionMode: selection,
        pdfTapMode: tap,
        capturesBoardInput: capture,
        snipTextOnly: rawSnip,
      ),
    ],
  );

  test('selection mode is opt-in and survives manifest roundtrip', () {
    expect(
      PluginToolContribution.fromJson({'id': 'a'}).textSelectionMode,
      false,
    );
    final parsed = PluginManifest.fromJson(manifest().toJson());
    expect(parsed.contributesTools.single.textSelectionMode, true);
  });
  test('only a permitted active selection toggle receives text', () {
    expect(PluginTextSelection.accepts(manifest(), 'term'), true);
    expect(PluginTextSelection.accepts(manifest(), 'other'), false);
    expect(PluginTextSelection.accepts(manifest(), null), false);
    expect(PluginTextSelection.accepts(null, 'term'), false);
    expect(
      PluginTextSelection.accepts(manifest(permission: false), 'term'),
      false,
    );
    expect(
      PluginTextSelection.accepts(manifest(selection: false), 'term'),
      false,
    );
    expect(PluginTextSelection.accepts(manifest(tap: true), 'term'), false);
    expect(PluginTextSelection.accepts(manifest(capture: true), 'term'), false);
    expect(
      PluginTextSelection.accepts(manifest(action: 'quick_input'), 'term'),
      false,
    );
  });
  test('raw snipping is explicit, permission-gated and roundtrips', () {
    final raw = manifest(action: 'snip_region', rawSnip: true);
    final parsed = PluginManifest.fromJson(raw.toJson());
    expect(parsed.contributesTools.single.snipTextOnly, true);
    expect(PluginToolContribution.fromJson({'id': 'a'}).snipTextOnly, false);
    expect(PluginTextSelection.acceptsSnippet(parsed, 'term'), true);
    expect(PluginTextSelection.prefersRawSnippets(parsed), true);
    expect(PluginTextSelection.acceptsSnippet(parsed, 'other'), false);
    expect(PluginTextSelection.acceptsSnippet(parsed, null), false);
    expect(PluginTextSelection.acceptsSnippet(null, 'term'), false);
    expect(
      PluginTextSelection.acceptsSnippet(
        manifest(action: 'snip_region'),
        'term',
      ),
      false,
    );
    expect(
      PluginTextSelection.acceptsSnippet(
        manifest(action: 'snip_region', rawSnip: true, permission: false),
        'term',
      ),
      false,
    );
    expect(
      PluginTextSelection.prefersRawSnippets(manifest(rawSnip: true)),
      false,
    );
    expect(PluginTextSelection.prefersRawSnippets(null), false);
  });
  test('selected terms normalize PDF whitespace without dropping accents', () {
    expect(PluginTextSelection.term('  vô\nhình\ttrung  '), 'vô hình trung');
    expect(PluginTextSelection.term('  '), null);
    expect(PluginTextSelection.term('a' * 501), null);
    expect(PluginTextSelection.term('a' * 500), hasLength(500));
  });
}
