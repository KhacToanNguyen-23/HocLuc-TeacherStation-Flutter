import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/models/subject_plugin.dart';
import 'package:teaching_companion/services/plugin_manager.dart';
import 'package:teaching_companion/widgets/studio/studio_plugins_marketplace_panel.dart';

class _SampleTestPlugin extends SubjectPlugin {
  @override
  String get id => 'sample_plugin';

  @override
  String get name => 'Tiện ích Mẫu';

  @override
  String get summary => 'Mô tả tóm tắt tiện ích kiểm thử';

  @override
  IconData get icon => Icons.calculate_rounded;

  @override
  Widget buildWidget(BuildContext context) {
    return const Text('Nội dung tiện ích mẫu');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PluginManager().resetForTesting();
  });

  group('Subject Plugins Framework & Google Meet Activities Panel tests', () {
    test('PluginManager registers, installs, and uninstalls plugins with persistence', () async {
      final manager = PluginManager();
      await manager.init();

      final plugin = _SampleTestPlugin();
      manager.registerPlugin(plugin);

      expect(manager.availablePlugins.contains(plugin), isTrue);
      expect(manager.isInstalled(plugin.id), isFalse);

      await manager.install(plugin.id);
      expect(manager.isInstalled(plugin.id), isTrue);
      expect(manager.installedPlugins.contains(plugin), isTrue);

      manager.openPlugin(plugin);
      expect(manager.activePlugin, equals(plugin));

      manager.closeActivePlugin();
      expect(manager.activePlugin, isNull);

      await manager.uninstall(plugin.id);
      expect(manager.isInstalled(plugin.id), isFalse);
    });

    testWidgets('StudioPluginsMarketplacePanel renders empty state when no plugins are registered', (tester) async {
      final manager = PluginManager();
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioPluginsMarketplacePanel(
              pluginManager: manager,
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Hoạt động & Tiện ích'), findsOneWidget);
      expect(find.text('Chưa có tiện ích bổ sung'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(closed, isTrue);
    });

    testWidgets('StudioPluginsMarketplacePanel displays plugin card and handles install action', (tester) async {
      final manager = PluginManager();
      final plugin = _SampleTestPlugin();
      manager.registerPlugin(plugin);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioPluginsMarketplacePanel(
              pluginManager: manager,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Tiện ích Mẫu'), findsOneWidget);
      expect(find.text('Cài đặt'), findsOneWidget);

      await tester.tap(find.text('Cài đặt'));
      await tester.pumpAndSettle();

      expect(manager.isInstalled(plugin.id), isTrue);
      expect(find.text('Mở'), findsOneWidget);
    });
  });
}
