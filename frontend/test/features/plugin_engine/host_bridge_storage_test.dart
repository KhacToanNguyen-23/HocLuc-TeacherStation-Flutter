import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_event_hub.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUp(() {
    storageDirectory = Directory.systemTemp.createTempSync('plugin_bridge_');
    PluginStorageManager.instance.setBaseDirectoryForTesting(storageDirectory);
  });

  tearDown(() {
    if (storageDirectory.existsSync()) {
      storageDirectory.deleteSync(recursive: true);
    }
  });

  test('plugin storage persists to disk and is scoped by plugin ID', () async {
    final studio = StudioState();
    final firstManifest = PluginManifest(
      id: 'com.hocluc.test.storage',
      name: 'Storage test',
      permissions: const ['storage'],
    );
    final secondManifest = PluginManifest(
      id: 'com.hocluc.test.other',
      name: 'Other plugin',
      permissions: const ['storage'],
    );

    await HostBridge.instance.handleMessage(
      rawMessage: {
        'action': 'storage:set',
        'payload': {'key': 'choice', 'value': 'enabled'},
      },
      studio: studio,
      manifest: firstManifest,
      executeJs: null,
    );

    final pluginValue = await HostBridge.instance.handleMessage(
      rawMessage: {
        'action': 'storage:get',
        'payload': {'key': 'choice'},
      },
      studio: studio,
      manifest: firstManifest,
      executeJs: null,
    );
    final isolatedValue = await HostBridge.instance.handleMessage(
      rawMessage: {
        'action': 'storage:get',
        'payload': {'key': 'choice'},
      },
      studio: studio,
      manifest: secondManifest,
      executeJs: null,
    );

    expect(pluginValue['data']['value'], 'enabled');
    expect(isolatedValue['data']['value'], isNull);
  });

  test('storage RPC is denied without the storage permission', () async {
    final response = await HostBridge.instance.handleMessage(
      rawMessage: {
        'action': 'storage:set',
        'payload': {'key': 'choice', 'value': 'enabled'},
      },
      studio: StudioState(),
      manifest: PluginManifest(
        id: 'com.hocluc.test.denied',
        name: 'No storage',
      ),
      executeJs: null,
    );

    expect(response['success'], isFalse);
    expect(response['error'], contains('storage'));
  });

  test(
    'declared PDF tool can be enabled and disabled through the SDK bridge',
    () async {
      final manifest = PluginManifest(
        id: 'com.hocluc.test.pdf_tool',
        name: 'PDF tool test',
        permissions: const ['board:control_tools'],
        contributesTools: const [
          PluginToolContribution(
            id: 'answer_marker',
            label: 'Answer marker',
            target: 'answer_marker',
            action: 'toggle_tool',
            pdfTapMode: true,
          ),
        ],
      );
      final studio = StudioState()
        ..activePlugin = InstalledPlugin(manifest: manifest);

      final enabled = await HostBridge.instance.handleMessage(
        rawMessage: {
          'action': 'board:set_tool',
          'payload': {'target': 'answer_marker', 'enabled': true},
        },
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );
      expect(enabled['data']['active'], isTrue);
      expect(studio.smartSnapEnabled, isTrue);

      final disabled = await HostBridge.instance.handleMessage(
        rawMessage: {
          'action': 'board:set_tool',
          'payload': {'target': 'answer_marker', 'enabled': false},
        },
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );
      expect(disabled['data']['active'], isFalse);
      expect(studio.smartSnapEnabled, isFalse);
    },
  );

  test('active PDF plugin can publish generic interactive regions', () async {
    final manifest = PluginManifest(
      id: 'com.hocluc.test.pdf_regions',
      name: 'PDF regions test',
      permissions: const ['board:publish_pdf_regions'],
      contributesTools: const [
        PluginToolContribution(
          id: 'pdf_region_tool',
          label: 'PDF regions',
          target: 'pdf_region_tool',
          pdfTapMode: true,
        ),
      ],
    );
    final studio = StudioState()
      ..activePlugin = InstalledPlugin(manifest: manifest)
      ..activeSubjectTool = 'pdf_region_tool'
      ..pdfTotalPages = 2;
    final incomingMessage = PluginEventHub.instance
        .messagesFor(manifest.id)
        .first;

    final response = await HostBridge.instance.handleMessage(
      rawMessage: {
        'action': 'board:publish_pdf_regions',
        'payload': {
          'page_number': 2,
          'document_generation': studio.pdfContentGeneration,
          'page_size': {'width': 612, 'height': 792},
          'regions': [
            {
              'id': 'region-1',
              'label': 'A',
              'group_id': 'group-1',
              'bounds': {'x': 10, 'y': 20, 'width': 14, 'height': 14},
            },
          ],
        },
      },
      studio: studio,
      manifest: manifest,
      executeJs: null,
    );
    final message = await incomingMessage;

    expect(response['data']['accepted'], isTrue);
    expect(response['data']['regionCount'], 1);
    expect(message.action, 'board:publish_pdf_regions');
    expect(message.payload['page_number'], 2);
  });

  test(
    'active PDF plugin can toggle a grouped PDF annotation through the bridge',
    () async {
      final manifest = PluginManifest(
        id: 'com.hocluc.test.pdf_annotation',
        name: 'PDF annotation test',
        permissions: const ['board:annotate_pdf'],
        contributesTools: const [
          PluginToolContribution(
            id: 'pdf_annotation_tool',
            label: 'PDF annotation',
            target: 'pdf_annotation_tool',
            pdfTapMode: true,
          ),
        ],
      );
      final studio = StudioState()
        ..activePlugin = InstalledPlugin(manifest: manifest)
        ..activeSubjectTool = 'pdf_annotation_tool';
      final message = {
        'action': 'board:toggle_pdf_annotation',
        'payload': {
          'page_number': 1,
          'document_generation': studio.pdfContentGeneration,
          'page_size': {'width': 612, 'height': 792},
          'region': {
            'id': 'region-A',
            'label': 'A',
            'group_id': 'question-1',
            'bounds': {'x': 30, 'y': 40, 'width': 20, 'height': 18},
          },
          'affected_pages': [1],
          'stroke': {
            'points': [
              [0.1, 0.2],
              [0.3, 0.2],
              [0.2, 0.4],
            ],
            'color': 0xff008800,
            'width': 3,
          },
        },
      };

      final staleMessage = {
        ...message,
        'payload': {
          ...(message['payload'] as Map<String, dynamic>),
          'document_generation': studio.pdfContentGeneration + 1,
        },
      };
      final stale = await HostBridge.instance.handleMessage(
        rawMessage: staleMessage,
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );
      expect(stale['success'], isFalse);
      expect(studio.pdfAnnotations[1], isNull);

      final first = await HostBridge.instance.handleMessage(
        rawMessage: message,
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );
      expect(first['success'], isTrue);
      expect(
        studio.pdfAnnotations[1]?.where(
          (stroke) => stroke.isGroupedPdfAnnotation,
        ),
        hasLength(1),
      );
      final saved = studio.pdfAnnotations[1]!.single;
      expect(saved.annotationOwnerId, manifest.id);
      expect(saved.smartPenGroupId, isNull);
      expect(saved.points.map((p) => [p.dx, p.dy]).toList(), [
        [0.1, 0.2],
        [0.3, 0.2],
        [0.2, 0.4],
      ]);
      final restored = BoardStroke.fromJson(saved.toJson());
      expect(restored.annotationGroupId, saved.annotationGroupId);
      expect(restored.annotationItemId, saved.annotationItemId);
      studio.undo();
      expect(studio.pdfAnnotations[1], isNull);
      studio.redo();
      expect(studio.pdfAnnotations[1]!.single.annotationItemId, 'region-A');

      final second = await HostBridge.instance.handleMessage(
        rawMessage: message,
        studio: studio,
        manifest: manifest,
        executeJs: null,
      );
      expect(second['success'], isTrue);
      expect(
        studio.pdfAnnotations[1]?.where(
          (stroke) => stroke.isGroupedPdfAnnotation,
        ),
        isEmpty,
      );
    },
  );
}
