import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/board_sticker.dart';
import '../models/plugin_manifest.dart';
import '../models/studio_state.dart';

/// Standard Host Bridge mediating Typed RPC messages between Plugin Webview and Studio State.
class HostBridge {
  static final HostBridge _instance = HostBridge._internal();
  factory HostBridge() => _instance;
  HostBridge._internal();

  static HostBridge get instance => _instance;

  final Map<String, Map<String, dynamic>> _pluginStorage = {};

  /// Handle an incoming message from the Webview (either raw JSON string or Map).
  Future<Map<String, dynamic>> handleMessage({
    required dynamic rawMessage,
    required StudioState studio,
    required PluginManifest? manifest,
    required void Function(String jsScript)? executeJs,
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
        case 'context:get':
          result = _successResponse(requestId, {
            'appVersion': '2.0.0',
            'platform': defaultTargetPlatform.name,
            'pluginId': pluginId,
            'pluginName': manifest?.name ?? '',
          });
          break;

        case 'board:get_selected_text':
          _enforcePermission(permissions, 'board:read_text');
          result = _successResponse(requestId, {'text': ''});
          break;

        case 'board:insert_annotation':
        case 'INSERT_ANNOTATION':
          _enforcePermission(permissions, 'board:insert_annotation');
          _handleInsertAnnotation(studio, manifest, payload);
          result = _successResponse(requestId, {'status': 'pinned'});
          break;

        case 'storage:get':
          final key = payload['key']?.toString() ?? '';
          final val = _pluginStorage[pluginId]?[key];
          result = _successResponse(requestId, {'key': key, 'value': val});
          break;

        case 'storage:set':
          final key = payload['key']?.toString() ?? '';
          final val = payload['value'];
          _pluginStorage.putIfAbsent(pluginId, () => {})[key] = val;
          result = _successResponse(requestId, {'success': true});
          break;

        case 'START_SNIP_SELECTION':
          studio.startSnipping(target: payload['target']?.toString() ?? 'svo');
          result = _successResponse(requestId, {'status': 'snipping_started'});
          break;

        case 'HIGHLIGHT_PDF_PASSAGE':
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
          studio.onApplyHighlightToPdfRequested?.call();
          result = _successResponse(requestId, {'status': 'applied'});
          break;

        case 'SAVE_HIGHLIGHTED_PDF':
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
    if (permissions.isNotEmpty && !permissions.contains(requiredPermission)) {
      throw StateError(
        'Permission denied: Missing required permission "$requiredPermission"',
      );
    }
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

    final sticker = BoardSticker(
      id: 'sticker-${DateTime.now().millisecondsSinceEpoch}',
      type: manifest?.id ?? 'generic_sticker',
      normalizedRect: const Rect.fromLTWH(0.2, 0.25, 0.45, 0.22),
      rawText: rawText,
      tokens: tokens,
      issues: issues,
    );
    studio.addSticker(sticker);

    if (studio.showPluginDrawer && !studio.pluginFloating) {
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
