import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:teaching_companion/core/utils/frontend_logger.dart';
import '../domain/models/studio_board_models.dart';

/// Container for loaded PDF annotation layer data.
class PdfAnnotationLayerData {
  const PdfAnnotationLayerData({
    required this.documentId,
    required this.annotations,
    this.highlightsVisible = true,
    this.savedAt,
    this.filePath,
  });

  final String documentId;
  final Map<int, List<BoardStroke>> annotations;
  final bool highlightsVisible;
  final String? savedAt;
  final String? filePath;

  int get totalAnnotations =>
      annotations.values.fold<int>(0, (sum, list) => sum + list.length);
}

/// Service that manages non-destructive persistence of PDF annotations
/// in local application storage or sidecar files, leaving the source PDF
/// 100% clean and unmodified.
class PdfAnnotationStorageService {
  PdfAnnotationStorageService({Directory? customStorageDirectory})
    : _customStorageDir = customStorageDirectory;

  final Directory? _customStorageDir;

  static const int currentSchemaVersion = 1;
  static final Map<String, Future<void>> _pendingWrites = {};
  static int _temporaryFileSequence = 0;

  /// Returns the base directory for storing PDF annotation layers.
  Directory getStorageDirectory() {
    final customDir = _customStorageDir;
    if (customDir != null) {
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }
      return customDir;
    }

    if (kIsWeb) {
      return Directory('/pdf_annotations');
    }

    String basePath;
    if (Platform.isWindows) {
      final localAppData =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          '${Platform.environment['USERPROFILE'] ?? ''}\\AppData\\Local';
      basePath = '$localAppData\\HocLuc\\pdf_annotations';
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '';
      basePath = '$home/Library/Application Support/HocLuc/pdf_annotations';
    } else {
      final home = Platform.environment['HOME'] ?? '';
      basePath = '$home/.local/share/hocluc/pdf_annotations';
    }

    final dir = Directory(basePath);
    if (!dir.existsSync()) {
      try {
        dir.createSync(recursive: true);
      } catch (e) {
        FrontendLogger.write(
          '[PdfAnnotationStorageService] Failed to create storage dir: $e',
        );
      }
    }
    return dir;
  }

  /// Computes a deterministic document ID from the canonical path and the
  /// SHA-256 digest of the complete PDF contents.
  Future<String> computeDocumentId({String? filePath, Uint8List? bytes}) async {
    final buffer = StringBuffer();
    final normalizedPath = filePath?.trim().replaceAll(r'\', '/');

    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      buffer.write(normalizedPath.toLowerCase());
    }

    Digest? contentDigest;
    var contentLength = bytes?.length;
    if (bytes != null) {
      contentDigest = sha256.convert(bytes);
    } else if (filePath != null && filePath.isNotEmpty) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          contentLength = await file.length();
          final digestSink = _SingleDigestSink();
          final inputSink = sha256.startChunkedConversion(digestSink);
          await for (final chunk in file.openRead()) {
            inputSink.add(chunk);
          }
          inputSink.close();
          contentDigest = digestSink.value;
        }
      } catch (_) {}
    }

    if (contentDigest != null) {
      buffer.write('_${contentLength}_${contentDigest.toString()}');
    }

    if (buffer.isEmpty) {
      buffer.write('doc_untitled');
    }

    final hash = sha256.convert(utf8.encode(buffer.toString())).toString();
    return 'doc_${hash.substring(0, 24)}';
  }

  /// Saves the annotation layer atomically to local storage without modifying the source PDF.
  Future<bool> saveAnnotations({
    required String documentId,
    String? filePath,
    required Map<int, List<BoardStroke>> annotations,
    bool highlightsVisible = true,
  }) async {
    try {
      final dir = getStorageDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final targetFile = File(
        '${dir.path}${Platform.pathSeparator}$documentId.json',
      );

      final serializedAnnotations = <String, List<Map<String, dynamic>>>{};
      for (final entry in annotations.entries) {
        if (entry.value.isNotEmpty) {
          serializedAnnotations[entry.key.toString()] = entry.value
              .map((stroke) => stroke.toJson())
              .toList();
        }
      }

      final payload = {
        'schemaVersion': currentSchemaVersion,
        'documentId': documentId,
        'filePath': filePath,
        'savedAt': DateTime.now().toIso8601String(),
        'highlightsVisible': highlightsVisible,
        'annotations': serializedAnnotations,
      };

      final jsonString = jsonEncode(payload);
      await _writeAtomically(targetFile, jsonString);

      // Also update sidecar file next to PDF if directory is writable
      if (filePath != null && filePath.isNotEmpty) {
        try {
          final sidecar = File('$filePath.hlann');
          await _writeAtomically(sidecar, jsonString);
        } catch (_) {
          // Non-critical if user PDF folder is read-only
        }
      }

      return true;
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationStorageService] saveAnnotations error: $e',
      );
      return false;
    }
  }

  /// Loads the saved annotation layer for a given document.
  Future<PdfAnnotationLayerData?> loadAnnotations({
    String? filePath,
    Uint8List? bytes,
    String? documentId,
  }) async {
    try {
      final docId =
          documentId ??
          await computeDocumentId(filePath: filePath, bytes: bytes);

      final dir = getStorageDirectory();
      final targetFile = File(
        '${dir.path}${Platform.pathSeparator}$docId.json',
      );

      String? content;
      if (targetFile.existsSync()) {
        content = targetFile.readAsStringSync();
      } else if (filePath != null && filePath.isNotEmpty) {
        final sidecar = File('$filePath.hlann');
        if (sidecar.existsSync()) {
          content = sidecar.readAsStringSync();
        }
      }

      if (content == null || content.trim().isEmpty) {
        return null;
      }

      final json = jsonDecode(content);
      if (json is! Map) return null;

      final dataMap = Map<String, dynamic>.from(json);
      if (dataMap['documentId'] != docId) {
        return null;
      }
      final rawAnnotations = dataMap['annotations'];
      final restored = <int, List<BoardStroke>>{};

      if (rawAnnotations is Map) {
        rawAnnotations.forEach((key, value) {
          final page = int.tryParse(key.toString());
          if (page != null && value is List) {
            restored[page] = value
                .map(
                  (item) => BoardStroke.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
          }
        });
      }

      final visible = dataMap['highlightsVisible'] as bool? ?? true;
      final savedAt = dataMap['savedAt'] as String?;
      final storedPath = dataMap['filePath'] as String?;

      return PdfAnnotationLayerData(
        documentId: docId,
        annotations: restored,
        highlightsVisible: visible,
        savedAt: savedAt,
        filePath: storedPath ?? filePath,
      );
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationStorageService] loadAnnotations error: $e',
      );
      return null;
    }
  }

  /// Deletes the saved annotation layer for a document.
  Future<bool> deleteAnnotations(String documentId, {String? filePath}) async {
    try {
      final dir = getStorageDirectory();
      final targetFile = File(
        '${dir.path}${Platform.pathSeparator}$documentId.json',
      );
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      if (filePath != null && filePath.isNotEmpty) {
        final sidecar = File('$filePath.hlann');
        if (sidecar.existsSync()) {
          sidecar.deleteSync();
        }
      }
      return true;
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationStorageService] deleteAnnotations error: $e',
      );
      return false;
    }
  }

  /// Detects whether an opened PDF already has legacy annotations baked into its page content.
  bool detectLegacyBakedPdf(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final text = latin1.decode(bytes, allowInvalid: true);
    return text.contains('Học Lực - Trợ giảng Tiếng Anh') ||
        text.contains('/Highlight') && text.contains('/Subtype /Highlight');
  }

  Future<void> _writeAtomically(File target, String contents) async {
    final targetPath = target.absolute.path;
    final previousWrite = _pendingWrites[targetPath] ?? Future<void>.value();
    final write = previousWrite
        .catchError((Object _) {})
        .then((_) => _replaceAtomically(target, contents));
    _pendingWrites[targetPath] = write;
    try {
      await write;
    } finally {
      if (identical(_pendingWrites[targetPath], write)) {
        _pendingWrites.remove(targetPath);
      }
    }
  }

  Future<void> _replaceAtomically(File target, String contents) async {
    final temporaryFile = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryFileSequence++}.tmp',
    );
    try {
      await temporaryFile.writeAsString(contents, flush: true);
      await temporaryFile.rename(target.path);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest digest) => value = digest;

  @override
  void close() {}
}
