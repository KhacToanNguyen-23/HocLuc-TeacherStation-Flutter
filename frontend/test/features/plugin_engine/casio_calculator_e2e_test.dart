import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_web_server.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/floating_plugin_window.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_plugins_marketplace_panel.dart';

File _findRealCasioHlep() {
  final candidates = [
    File('plugins/casio_calculator.hlep'),
    File('../plugins/casio_calculator.hlep'),
    File('../../plugins/casio_calculator.hlep'),
  ];
  for (final f in candidates) {
    if (f.existsSync()) return f;
  }
  throw StateError('Không tìm thấy tệp thật plugins/casio_calculator.hlep');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempInstallDir;

  setUp(() async {
    HttpOverrides.global = null; // Cho phép kết nối HTTP loopback thật 100%
    SharedPreferences.setMockInitialValues({});
    tempInstallDir = await Directory.systemTemp.createTemp('hocluc_casio_real_');
    PluginStorageManager.instance.setBaseDirectoryForTesting(tempInstallDir);
    PluginManager.instance.resetForTesting();
  });

  tearDown(() async {
    await PluginWebServer.instance.stop();
    PluginManager.instance.resetForTesting();
    if (tempInstallDir.existsSync()) {
      await tempInstallDir.delete(recursive: true);
    }
  });

  group('Real Casio Calculator (.hlep) End-to-End Verification (Zero Mock Data)', () {
    test(
      '1. Giải nén gói thật plugins/casio_calculator.hlep và phục vụ toàn bộ tài nguyên Web/JS/CSS/Audio qua PluginWebServer thật',
      () async {
        final realHlep = _findRealCasioHlep();
        final hlepBytes = await realHlep.readAsBytes();
        expect(hlepBytes.length, greaterThan(500000));

        // Cài đặt gói thật vào ổ cứng
        final installed = await PluginManager.instance.installPluginFromBytes(
          hlepBytes,
          'casio_calculator.hlep',
        );

        expect(installed.id, equals('com.hocluc.plugin.casio'));
        expect(installed.name, equals('Máy Tính Khoa Học Casio'));
        expect(installed.manifest.uiPlacement, equals('floating_window'));
        expect(installed.manifest.frameless, isTrue);
        expect(installed.manifest.injectSdk, isTrue);
        expect(installed.iconFile, isNotNull);
        expect(installed.iconFile!.existsSync(), isTrue);

        // Khởi động máy chủ HTTP cục bộ thật
        final port = await PluginWebServer.instance.start();
        expect(port, greaterThan(1024));

        final client = HttpClient();
        try {
          // Kiểm tra trang chính ui/index.html có tự động tiêm SDK và nhúng embed.css không
          final indexUrl = PluginWebServer.instance.getUrl(
            installed.id,
            installed.manifest.uiEntry,
          )!;
          final req1 = await client.getUrl(Uri.parse(indexUrl));
          final res1 = await req1.close();
          final html = await res1.transform(SystemEncoding().decoder).join();

          expect(res1.statusCode, equals(200));
          expect(html, contains('<title>HocLuc Calculator</title>'));
          expect(html, contains('embed.css'));
          expect(
            html,
            contains('<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>'),
            reason: 'PluginWebServer phải tự động tiêm SDK cho Casio Open-Source UI',
          );

          // Kiểm tra tải embed.css ẩn toàn bộ khung trắng & header/footer thừa
          final cssUrl = PluginWebServer.instance.getUrl(
            installed.id,
            'ui/embed.css',
          )!;
          final reqCss = await client.getUrl(Uri.parse(cssUrl));
          final resCss = await reqCss.close();
          final cssText = await resCss.transform(SystemEncoding().decoder).join();
          expect(resCss.statusCode, equals(200));
          expect(cssText, contains('.calculator-app-heading'));
          expect(cssText, contains('display: none !important'));

          // Kiểm tra tải bundle JS thật của Casio
          final jsUrl = PluginWebServer.instance.getUrl(
            installed.id,
            'ui/assets/index-lsawh5IG.js',
          )!;
          final req2 = await client.getUrl(Uri.parse(jsUrl));
          final res2 = await req2.close();
          final jsBytes = await res2.fold<List<int>>([], (a, b) => a..addAll(b));
          expect(res2.statusCode, equals(200));
          expect(jsBytes.length, greaterThan(100000));

          // Kiểm tra tải âm thanh bàn phím cơ thật của Casio qua đường dẫn tuyệt đối gốc (/audio/...) như trong bundle Vite
          final rootRelativeWavUrl =
              'http://127.0.0.1:$port/audio/nk-cream-click-quiet-v6.wav';
          final req3 = await client.getUrl(Uri.parse(rootRelativeWavUrl));
          final res3 = await req3.close();
          expect(res3.statusCode, equals(200));
        } finally {
          client.close(force: true);
        }
      },
    );

    testWidgets(
      '2. Phát hiện gói thật từ thư mục plugins/, cài đặt trên Kho Tiện Ích và mở cửa sổ nổi Casio sát viền (Frameless) trên bảng phấn',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Quét thư mục plugins/ thật của dự án (không mock)
        await PluginManager.instance.discoverAvailablePlugins();

        final casioInCatalog = PluginManager.instance.availablePlugins
            .where((p) => p.id == 'com.hocluc.plugin.casio')
            .toList();
        expect(
          casioInCatalog,
          isNotEmpty,
          reason: 'Phải tự động tìm thấy gói thật com.hocluc.plugin.casio trong thư mục plugins/',
        );

        final studio = StudioState();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  StudioPluginsMarketplacePanel(
                    pluginManager: PluginManager.instance,
                    autoSyncOnOpen: false,
                    onClose: () {},
                    onOpenPlugin: (plugin) {
                      if (plugin is InstalledPlugin) {
                        studio.openPlugin(
                          plugin,
                          openModal:
                              plugin.manifest.uiPlacement != 'floating_window',
                        );
                      }
                    },
                  ),
                  FloatingPluginWindow(studio: studio),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Thẻ Máy Tính Khoa Học Casio hiển thị trên Kho Tiện Ích
        expect(find.text('Máy Tính Khoa Học Casio'), findsOneWidget);
        expect(find.text('Cửa sổ nổi'), findsOneWidget);

        // Bấm nút Cài đặt cho Máy Tính Khoa Học Casio
        final casioCard = find.ancestor(
          of: find.text('Máy Tính Khoa Học Casio'),
          matching: find.byType(Container),
        );
        final installBtn = find.descendant(
          of: casioCard.first,
          matching: find.text('Cài đặt'),
        );
        await tester.tap(installBtn);
        await tester.pumpAndSettle();

        expect(
          PluginManager.instance.isInstalled('com.hocluc.plugin.casio'),
          isTrue,
        );

        // Bấm nút Mở -> Cửa sổ nổi Casio xuất hiện ở chế độ sát viền (Frameless)
        final openBtn = find.descendant(
          of: casioCard.first,
          matching: find.text('Mở'),
        );
        await tester.tap(openBtn);
        await tester.pump();

        expect(studio.floatingPlugin?.id, equals('com.hocluc.plugin.casio'));
        expect(studio.pluginFloating, isTrue);
        expect(studio.pluginFloatingSize, equals(const Size(336, 624)));
        expect(
          find.byKey(const Key('frameless_floating_plugin_container')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('frameless_plugin_drag_bezel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('frameless_plugin_close_button')),
          findsOneWidget,
        );
      },
    );
  });
}

