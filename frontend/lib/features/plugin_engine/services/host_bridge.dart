import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_pdf_region.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_storage_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_event_hub.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

/// Standard Host Bridge mediating Typed RPC messages between Plugin Webview and Studio State.
class HostBridge {
  static final HostBridge _instance = HostBridge._internal();
  factory HostBridge() => _instance;
  HostBridge._internal();

  static HostBridge get instance => _instance;

  GlassRegionService get glassRegions => GlassRegionService.instance;

  /// Broadcasts a generic glass preference to all live views for a plugin.
  void notifyGlassPreset({
    required String pluginId,
    required GlassPreset preset,
  }) {
    PluginEventHub.instance.dispatch(pluginId, 'GLASS_PRESET_CHANGE', {
      'preset': preset.name,
      'dispatched_at_epoch_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Broadcasts workspace mode (normal or pdf) to all live views for a plugin.
  void notifyWorkspaceMode({
    required String pluginId,
    required bool isPdfMode,
  }) {
    PluginEventHub.instance.dispatch(pluginId, 'WORKSPACE_MODE_CHANGE', {
      'workspace_mode': isPdfMode ? 'pdf' : 'normal',
      'dispatched_at_epoch_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Registers a mounted plugin view and applies the host's current preset to
  /// that view after its page has completed navigation.
  void registerPluginView({
    required String pluginId,
    required GlassPreset preset,
    required void Function(String) sender,
    bool isPdfMode = false,
  }) {
    PluginEventHub.instance.register(
      pluginId,
      sender,
      initialGlassPresetPayload: {
        'preset': preset.name,
        'workspace_mode': isPdfMode ? 'pdf' : 'normal',
        'dispatched_at_epoch_ms': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Handle an incoming message from the Webview (either raw JSON string or Map).
  Future<Map<String, dynamic>> handleMessage({
    required dynamic rawMessage,
    required StudioState studio,
    required PluginManifest? manifest,
    required void Function(String jsScript)? executeJs,
    String? viewToken,
    int? navigationGeneration,
    Rect? webViewBounds,
  }) async {
    Map<String, dynamic> data;
    try {
      if (rawMessage is String) {
        data = jsonDecode(rawMessage) as Map<String, dynamic>;
      } else if (rawMessage is Map) {
        data = Map<String, dynamic>.from(rawMessage);
      } else {
        return _errorResponse(
          'invalid_format',
          'Message must be JSON string or Map',
        );
      }
    } catch (e) {
      return _errorResponse('parse_error', 'Failed to parse message: $e');
    }

    final requestId = data['id']?.toString();
    final action = data['action']?.toString() ?? data['type']?.toString() ?? '';
    final payload = (data['payload'] is Map)
        ? Map<String, dynamic>.from(data['payload'] as Map)
        : data;

    final pluginId = manifest?.id ?? 'unknown_plugin';
    final permissions = manifest?.permissions ?? const [];

    FrontendLogger.write(
      '[HostBridge] Plugin $pluginId -> action: $action (id: $requestId)',
    );

    Map<String, dynamic> result;
    try {
      switch (action) {
        case 'glass:register':
        case 'glass:update':
        case 'glass:unregister':
          final isActivePlugin =
              studio.activePlugin?.id == pluginId ||
              studio.floatingPlugin?.id == pluginId;
          if (!isActivePlugin) {
            throw StateError('Plugin view is not active.');
          }
          if (viewToken == null ||
              navigationGeneration == null ||
              webViewBounds == null) {
            throw StateError('Missing WebView context for glass region.');
          }
          final messageGeneration = (data['host_generation'] as num?)?.toInt();
          if (messageGeneration != navigationGeneration) {
            throw const FormatException('Stale glass region document message.');
          }
          final accepted = glassRegions.handleMessage(
            viewToken: viewToken,
            pluginId: pluginId,
            navigationGeneration: navigationGeneration,
            action: action,
            payload: payload,
            webViewBounds: webViewBounds,
          );
          if (!accepted) {
            throw const FormatException('Invalid or stale glass region.');
          }
          result = _successResponse(requestId, {
            'accepted': true,
            if (payload['region_id'] is String)
              'regionId': payload['region_id'],
          });
          break;

        case 'context:get':
          result = _successResponse(requestId, {
            'appVersion': '2.0.0',
            'platform': defaultTargetPlatform.name,
            'pluginId': pluginId,
            'pluginName': manifest?.name ?? '',
            'editingSticker': studio.editingSticker != null
                ? {
                    'id': studio.editingSticker!.id,
                    'title': studio.editingSticker!.title,
                    'metadata': studio.editingSticker!.metadata,
                    'formula': studio.editingSticker!.metadata?['formula'] ??
                        studio.editingSticker!.title?.replaceAll(RegExp(r'^(Đồ thị:\s*|y\s*=\s*)'), '').trim(),
                    'a': studio.editingSticker!.metadata?['a'],
                    'b': studio.editingSticker!.metadata?['b'],
                    'view': studio.editingSticker!.metadata?['view'],
                  }
                : null,
            'activeTool':
                manifest?.contributesTools.any(
                      (tool) =>
                          (tool.target ?? tool.id) == studio.activeSubjectTool,
                    ) ==
                    true
                ? studio.activeSubjectTool
                : null,
          });
          break;

        case 'board:get_selected_text':
          _enforcePermission(permissions, 'board:read_text');
          result = _successResponse(requestId, {'text': ''});
          break;

        case 'board:set_tool':
          _enforcePermission(permissions, 'board:control_tools');
          final target = payload['target']?.toString() ?? '';
          final enabled = payload['enabled'] == true;
          final declared =
              manifest?.contributesTools.any(
                (tool) =>
                    tool.action == 'toggle_tool' &&
                    (tool.target ?? tool.id) == target,
              ) ??
              false;
          if (!declared) {
            throw StateError('Tool is not declared by this plugin.');
          }
          studio.setActiveSubjectTool(
            enabled
                ? target
                : (studio.activeSubjectTool == target
                      ? null
                      : studio.activeSubjectTool),
          );
          result = _successResponse(requestId, {
            'active': studio.activeSubjectTool == target,
          });
          break;

        case 'board:publish_pdf_regions':
          _enforcePermission(permissions, 'board:publish_pdf_regions');
          final isActivePlugin =
              studio.activePlugin?.id == pluginId ||
              studio.floatingPlugin?.id == pluginId;
          if (!isActivePlugin) {
            throw StateError('Plugin is not active in the board.');
          }
          final pageNumber = (payload['page_number'] as num?)?.toInt();
          final generation = (payload['document_generation'] as num?)?.toInt();
          final activeTarget = studio.activeSubjectTool;
          final ownsActivePdfTool =
              manifest?.contributesTools.any(
                (tool) =>
                    tool.action == 'toggle_tool' &&
                    tool.pdfTapMode &&
                    (tool.target ?? tool.id) == activeTarget,
              ) ??
              false;
          if (pageNumber == null || pageNumber < 1 || generation == null) {
            throw const FormatException('Invalid PDF page metadata.');
          }
          if (generation != studio.pdfContentGeneration ||
              pageNumber > studio.pdfTotalPages) {
            throw const FormatException(
              'PDF document or page is no longer active.',
            );
          }
          if (!ownsActivePdfTool) {
            throw StateError('Plugin has no active PDF tool.');
          }
          final regions = payload['regions'];
          final rawPageSize = payload['page_size'];
          if (regions is! List ||
              regions.length > 2000 ||
              rawPageSize is! Map) {
            throw const FormatException('Invalid PDF regions payload.');
          }
          final pageWidth = _finiteNumber(rawPageSize['width']);
          final pageHeight = _finiteNumber(rawPageSize['height']);
          if (pageWidth == null ||
              pageHeight == null ||
              pageWidth <= 0 ||
              pageHeight <= 0) {
            throw const FormatException('Invalid PDF page size.');
          }
          final parsedRegions = regions
              .map(PluginPdfRegion.tryParse)
              .toList(growable: false);
          if (parsedRegions.any((region) => region == null)) {
            throw const FormatException('A PDF region has invalid geometry.');
          }
          for (final region in parsedRegions.cast<PluginPdfRegion>()) {
            if (region.bounds.right > pageWidth ||
                region.bounds.bottom > pageHeight) {
              throw const FormatException('A PDF region exceeds page bounds.');
            }
          }
          PluginEventHub.instance.receiveFromPlugin(
            pluginId: pluginId,
            action: action,
            payload: {
              'page_number': pageNumber,
              'document_generation': generation,
              'page_size': {'width': pageWidth, 'height': pageHeight},
              'regions': parsedRegions
                  .cast<PluginPdfRegion>()
                  .map((region) => region.toJson())
                  .toList(growable: false),
            },
          );
          result = _successResponse(requestId, {
            'accepted': true,
            'pageNumber': pageNumber,
            'regionCount': regions.length,
          });
          break;

        case 'board:rekey_pdf_annotation_group':
          _enforcePermission(permissions, 'board:annotate_pdf');
          final ownsActiveTool =
              manifest?.contributesTools.any(
                (tool) =>
                    tool.action == 'toggle_tool' &&
                    tool.pdfTapMode &&
                    (tool.target ?? tool.id) == studio.activeSubjectTool,
              ) ??
              false;
          if ((studio.activePlugin?.id != pluginId &&
                  studio.floatingPlugin?.id != pluginId) ||
              !ownsActiveTool ||
              payload['document_generation'] != studio.pdfContentGeneration) {
            throw StateError('Plugin tool or PDF is no longer active.');
          }
          final from = payload['from_group_id'];
          final to = payload['to_group_id'];
          final pages = payload['affected_pages'];
          if (from is! String ||
              to is! String ||
              from.isEmpty ||
              to.isEmpty ||
              from.length > 512 ||
              to.length > 512 ||
              pages is! List ||
              pages.any(
                (p) => p is! int || p < 1 || p > studio.pdfTotalPages,
              )) {
            throw const FormatException('Invalid annotation group migration.');
          }
          studio.migratePdfAnnotationGroup(
            jsonEncode([pluginId, from]),
            jsonEncode([pluginId, to]),
            affectedPages: pages.cast<int>(),
          );
          result = _successResponse(requestId, {'accepted': true});
          break;

        case 'board:toggle_pdf_annotation':
          _enforcePermission(permissions, 'board:annotate_pdf');
          final isActivePlugin =
              studio.activePlugin?.id == pluginId ||
              studio.floatingPlugin?.id == pluginId;
          if (!isActivePlugin) {
            throw StateError('Plugin is not active in the board.');
          }
          final activeTarget = studio.activeSubjectTool;
          final ownsActivePdfTool =
              manifest?.contributesTools.any(
                (tool) =>
                    tool.action == 'toggle_tool' &&
                    tool.pdfTapMode &&
                    (tool.target ?? tool.id) == activeTarget,
              ) ??
              false;
          if (!ownsActivePdfTool) {
            throw StateError('Plugin has no active PDF tool.');
          }
          final pageNumber = (payload['page_number'] as num?)?.toInt();
          final generation = (payload['document_generation'] as num?)?.toInt();
          if (pageNumber == null ||
              pageNumber < 1 ||
              pageNumber > studio.pdfTotalPages ||
              generation != studio.pdfContentGeneration) {
            throw const FormatException(
              'PDF document or page is no longer active.',
            );
          }
          final rawPageSize = payload['page_size'];
          final region = PluginPdfRegion.tryParse(payload['region']);
          if (rawPageSize is! Map || region == null) {
            throw const FormatException('Invalid PDF annotation geometry.');
          }
          final pageWidth = _finiteNumber(rawPageSize['width']);
          final pageHeight = _finiteNumber(rawPageSize['height']);
          if (pageWidth == null ||
              pageHeight == null ||
              pageWidth <= 0 ||
              pageHeight <= 0 ||
              region.bounds.right > pageWidth ||
              region.bounds.bottom > pageHeight) {
            throw const FormatException('PDF annotation exceeds page bounds.');
          }
          final rawAffectedPages = payload['affected_pages'];
          final affectedPages = rawAffectedPages is List
              ? rawAffectedPages
                    .whereType<num>()
                    .map((page) => page.toInt())
                    .where((page) => page >= 1 && page <= studio.pdfTotalPages)
                    .toSet()
                    .toList()
              : <int>[];
          affectedPages.add(pageNumber);
          final strokeData = payload['stroke'];
          if (strokeData is! Map || strokeData['points'] is! List) {
            throw const FormatException(
              'Plugin must supply annotation points.',
            );
          }
          final rawPoints = strokeData['points'] as List;
          final color = strokeData['color'];
          final width = _finiteNumber(strokeData['width']);
          if (rawPoints.length < 3 ||
              rawPoints.length > 512 ||
              color is! int ||
              color < 0 ||
              color > 0xffffffff ||
              width == null ||
              width <= 0 ||
              width > 64) {
            throw const FormatException('Invalid annotation path or style.');
          }
          final points = <Offset>[];
          for (final value in rawPoints) {
            if (value is! List || value.length != 2) {
              throw const FormatException('Invalid annotation point.');
            }
            final x = _finiteNumber(value[0]);
            final y = _finiteNumber(value[1]);
            if (x == null || y == null || x < 0 || x > 1 || y < 0 || y > 1) {
              throw const FormatException(
                'Annotation points must be normalized.',
              );
            }
            points.add(Offset(x, y));
          }
          studio.togglePluginPdfAnnotation(
            pageNumber: pageNumber,
            annotation: BoardStroke(
              Color(color),
              width,
              points,
              isHollow: true,
              annotationOwnerId: pluginId,
              annotationGroupId: jsonEncode([pluginId, region.groupId]),
              annotationItemId: region.id,
            ),
            persist: payload['persist'] != false,
            affectedPages: affectedPages,
          );
          result = _successResponse(requestId, {'accepted': true});
          break;

        case 'board:insert_annotation':
        case 'INSERT_ANNOTATION':
          _enforcePermission(permissions, 'board:insert_annotation');
          _handleInsertAnnotation(studio, manifest, payload);
          result = _successResponse(requestId, {'status': 'pinned'});
          break;

        case 'window:close':
          if (studio.pluginFloating) {
            studio.closeFloatingPlugin();
          } else {
            studio.showPluginDrawer = false;
          }
          result = _successResponse(requestId, {'closed': true});
          break;

        case 'storage:get':
          _enforcePermission(permissions, 'storage');
          final key = payload['key']?.toString() ?? '';
          final file = PluginStorageManager.instance.getPluginDataFile(
            pluginId,
            'storage.json',
          );
          Map<String, dynamic> values = {};
          if (await file.exists()) {
            values = (jsonDecode(await file.readAsString()) as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
          final val = values[key];
          result = _successResponse(requestId, {'key': key, 'value': val});
          break;

        case 'storage:set':
          _enforcePermission(permissions, 'storage');
          final key = payload['key']?.toString() ?? '';
          final val = payload['value'];
          final file = PluginStorageManager.instance.getPluginDataFile(
            pluginId,
            'storage.json',
          );
          Map<String, dynamic> values = {};
          if (await file.exists()) {
            values = (jsonDecode(await file.readAsString()) as Map).map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
          values[key] = val;
          await file.writeAsString(jsonEncode(values), flush: true);
          result = _successResponse(requestId, {'success': true});
          break;

        case 'START_SNIP_SELECTION':
          _enforcePermission(permissions, 'board:read_text');
          studio.startSnipping(target: payload['target']?.toString() ?? '');
          result = _successResponse(requestId, {'status': 'snipping_started'});
          break;

        case 'HIGHLIGHT_PDF_PASSAGE':
          _enforcePermission(permissions, 'board:highlight_pdf');
          final rawText = (payload['text'] as String?)?.trim() ?? '';
          final rawHighlights =
              (payload['highlights'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          final metrics = (payload['metrics'] as Map<String, dynamic>?) ?? {};
          if (rawText.isNotEmpty) {
            studio.highlightPdfPassageFromAnalysis(
              rawText,
              rawHighlights,
              metrics: metrics,
            );
          }
          result = _successResponse(requestId, {'status': 'pdf_highlighted'});
          break;

        case 'APPLY_HIGHLIGHT_TO_PDF':
          _enforcePermission(permissions, 'board:highlight_pdf');
          studio.onApplyHighlightToPdfRequested?.call();
          result = _successResponse(requestId, {'status': 'applied'});
          break;

        case 'SAVE_HIGHLIGHTED_PDF':
          _enforcePermission(permissions, 'board:highlight_pdf');
          studio.onSaveHighlightedPdfRequested?.call();
          result = _successResponse(requestId, {'status': 'saved'});
          break;

        default:
          result = _successResponse(requestId, {'status': 'ignored'});
      }
    } catch (e) {
      FrontendLogger.write('[HostBridge] Error executing $action: $e');
      result = _errorResponse(requestId, e.toString());
    }

    // Return response to Webview via JS handler if requestId was provided
    if (requestId != null && executeJs != null) {
      final jsonResponse = jsonEncode(result);
      final jsCall =
          'window.__hocluc_handle_response && window.__hocluc_handle_response($jsonResponse);';
      executeJs(jsCall);
    }

    return result;
  }

  void _enforcePermission(List<String> permissions, String requiredPermission) {
    if (!permissions.contains(requiredPermission)) {
      throw StateError(
        'Permission denied: Missing required permission "$requiredPermission"',
      );
    }
  }

  double? _finiteNumber(Object? value) {
    if (value is! num) return null;
    final number = value.toDouble();
    return number.isFinite ? number : null;
  }

  void _handleInsertAnnotation(
    StudioState studio,
    PluginManifest? manifest,
    Map<String, dynamic> payload,
  ) {
    final innerData = (payload['data'] is Map)
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;

    final rawText =
        (innerData['raw_text'] as String?) ??
        (innerData['rawText'] as String?) ??
        (innerData['text'] as String?) ??
        '';

    final tokens =
        (innerData['tokens'] as List?)
            ?.map((t) => Map<String, dynamic>.from(t as Map))
            .toList() ??
        const [];

    List<String> issues = [];
    if (innerData['issues'] is List) {
      issues = (innerData['issues'] as List).map((e) => e.toString()).toList();
    } else if (innerData['grammarIssue'] != null) {
      issues = [innerData['grammarIssue'].toString()];
    } else if (innerData['grammar_issue'] != null) {
      issues = [innerData['grammar_issue'].toString()];
    }

    final title = (innerData['title'] as String?)?.trim();
    final svgContent =
        (innerData['svgContent'] as String?) ??
        (innerData['svg'] as String?);
    final imageBase64 =
        (innerData['imageBase64'] as String?) ??
        (innerData['image'] as String?);

    final stickerId = (innerData['stickerId'] as String?) ??
        (innerData['id'] as String?) ??
        (payload['stickerId'] as String?);

    final metadata = (innerData['metadata'] is Map)
        ? Map<String, dynamic>.from(innerData['metadata'] as Map)
        : (payload['metadata'] is Map)
            ? Map<String, dynamic>.from(payload['metadata'] as Map)
            : null;

    final existingIndex = stickerId != null
        ? studio.currentStickers.indexWhere((s) => s.id == stickerId)
        : -1;

    if (existingIndex != -1) {
      final existing = studio.currentStickers[existingIndex];
      final updated = existing.copyWith(
        title: title ?? existing.title,
        svgContent: svgContent ?? existing.svgContent,
        imageBase64: imageBase64 ?? existing.imageBase64,
        rawText: rawText.isNotEmpty ? rawText : existing.rawText,
        tokens: tokens.isNotEmpty ? tokens : existing.tokens,
        issues: issues.isNotEmpty ? issues : existing.issues,
        metadata: metadata ?? existing.metadata,
      );
      studio.updateSticker(updated);
    } else {
      final isGraphOrBbt = svgContent != null && svgContent.isNotEmpty;
      final passedAspect = (innerData['aspectRatio'] as num?)?.toDouble() ??
          (innerData['aspect'] as num?)?.toDouble() ??
          (payload['aspectRatio'] as num?)?.toDouble();

      Rect initialRect;
      if (passedAspect != null && passedAspect > 0) {
        const boardAspect = 16.0 / 9.0;
        final normH = (passedAspect > 1.6) ? 0.30 : 0.44;
        final normW = (normH * (passedAspect / boardAspect)).clamp(0.18, 0.85);
        final normLeft = ((1.0 - normW) / 2.0).clamp(0.05, 0.8);
        final normTop = ((1.0 - normH) / 2.0).clamp(0.05, 0.8);
        initialRect = Rect.fromLTWH(normLeft, normTop, normW, normH);
      } else if (isGraphOrBbt) {
        // Default square aspect ratio on 16:9 board (0.248 x 1920 ~= 476px, 0.44 x 1080 ~= 475px -> 1:1 square)
        initialRect = const Rect.fromLTWH(0.376, 0.28, 0.248, 0.44);
      } else {
        initialRect = const Rect.fromLTWH(0.25, 0.25, 0.45, 0.22);
      }

      final stickerType = (innerData['pluginId'] as String?) ??
          (innerData['type'] as String?) ??
          manifest?.id ??
          studio.activePlugin?.manifest.id ??
          'generic_sticker';

      final sticker = BoardSticker(
        id: stickerId ?? 'sticker-${DateTime.now().millisecondsSinceEpoch}',
        type: stickerType,
        normalizedRect: initialRect,
        rawText: rawText,
        title: title,
        svgContent: svgContent,
        imageBase64: imageBase64,
        tokens: tokens,
        issues: issues,
        metadata: metadata,
      );
      studio.addSticker(sticker);
    }

    // Auto-close or minimize plugin window so teacher immediately sees and interacts with the sticker on chalkboard
    if (studio.pluginFloating) {
      studio.closeFloatingPlugin();
    } else if (studio.showPluginDrawer) {
      studio.showPluginDrawer = false;
    }
  }

  Map<String, dynamic> _successResponse(String? id, dynamic data) => {
    'id': id,
    'success': true,
    'data': data,
  };

  Map<String, dynamic> _errorResponse(String? id, String error) => {
    'id': id,
    'success': false,
    'error': error,
  };
}
