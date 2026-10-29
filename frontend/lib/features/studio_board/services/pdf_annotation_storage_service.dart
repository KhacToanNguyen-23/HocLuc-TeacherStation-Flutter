import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:teaching_companion/core/utils/frontend_logger.dart';
import '../domain/models/studio_board_models.dart';
import 'pdf_annotation_save_diagnostics.dart';

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
  Future<String> computeDocumentId({
    String? filePath,
    Uint8List? bytes,
    String? contentSha256,
    int? contentLength,
    String? operationId,
  }) async {
    final totalTimer = Stopwatch()..start();
    final buffer = StringBuffer();
    final normalizedPath = filePath?.trim().replaceAll(r'\', '/');

    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      buffer.write(normalizedPath.toLowerCase());
    }

    String? contentDigest;
    var resolvedContentLength = contentLength ?? bytes?.length;
    if (bytes != null) {
      final hashTimer = Stopwatch()..start();
      contentDigest = contentSha256 ?? sha256.convert(bytes).toString();
      if (operationId != null) {
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'identity_sha256',
          duration: hashTimer.elapsed,
          fields: {
            'source': contentSha256 == null
                ? 'pdf_bytes'
                : 'cached_fingerprint',
            'pdfBytes': bytes.length,
            'executed': contentSha256 == null,
          },
        );
      }
    } else if (filePath != null && filePath.isNotEmpty) {
      final fileHashTimer = Stopwatch()..start();
      try {
        final file = File(filePath);
        if (await file.exists()) {
          resolvedContentLength = await file.length();
          final hashTimer = Stopwatch()..start();
          final digestSink = _SingleDigestSink();
          final inputSink = sha256.startChunkedConversion(digestSink);
          await for (final chunk in file.openRead()) {
            inputSink.add(chunk);
          }
          inputSink.close();
          contentDigest = digestSink.value.toString();
          if (operationId != null) {
            PdfAnnotationSaveDiagnostics.log(
              operationId,
              'identity_sha256',
              duration: hashTimer.elapsed,
              fields: {
                'source': 'pdf_file_stream',
                'pdfBytes': resolvedContentLength,
                'executed': true,
              },
            );
          }
        }
      } catch (error) {
        if (operationId != null) {
          PdfAnnotationSaveDiagnostics.log(
            operationId,
            'identity_sha256',
            duration: fileHashTimer.elapsed,
            fields: {
              'source': 'pdf_file_stream',
              'status': 'warning',
              'errorType': error.runtimeType,
            },
          );
        }
      }
    }

    if (contentDigest != null) {
      buffer.write('_${resolvedContentLength}_$contentDigest');
    }

    if (buffer.isEmpty) {
      buffer.write('doc_untitled');
    }

    final hash = sha256.convert(utf8.encode(buffer.toString())).toString();
    final documentId = 'doc_${hash.substring(0, 24)}';
    if (operationId != null) {
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'document_identity',
        duration: totalTimer.elapsed,
        fields: {
          'status': 'success',
          'pdfBytes': resolvedContentLength ?? 0,
          'contentHashUsed': contentDigest != null,
        },
      );
    }
    return documentId;
  }

  /// Saves the annotation layer atomically to local storage without modifying the source PDF.
  Future<bool> saveAnnotations({
    required String documentId,
    String? filePath,
    required Map<int, List<BoardStroke>> annotations,
    bool highlightsVisible = true,
    String? operationId,
    int? pdfBytesLength,
  }) async {
    final saveOperationId =
        operationId ?? PdfAnnotationSaveDiagnostics.newOperationId();
    final totalTimer = Stopwatch()..start();
    try {
      final directoryTimer = Stopwatch()..start();
      final dir = getStorageDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'storage_directory_setup',
        duration: directoryTimer.elapsed,
      );

      final targetFile = File(
        '${dir.path}${Platform.pathSeparator}$documentId.json',
      );

      final serializationTimer = Stopwatch()..start();
      final serializedAnnotations = <String, List<Map<String, dynamic>>>{};
      var annotationCount = 0;
      late final Uint8List payloadBytes;
      try {
        for (final entry in annotations.entries) {
          if (entry.value.isNotEmpty) {
            annotationCount += entry.value.length;
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

        payloadBytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      } catch (error) {
        PdfAnnotationSaveDiagnostics.log(
          saveOperationId,
          'json_serialization',
          duration: serializationTimer.elapsed,
          fields: {
            'annotations': annotationCount,
            'status': 'error',
            'errorType': error.runtimeType,
          },
        );
        rethrow;
      }
      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'json_serialization',
        duration: serializationTimer.elapsed,
        fields: {
          'annotations': annotationCount,
          'pages': serializedAnnotations.length,
          'payloadBytes': payloadBytes.length,
        },
      );

      final appDataTimer = Stopwatch()..start();
      try {
        await _writeAtomically(
          targetFile,
          payloadBytes,
          operationId: saveOperationId,
          destination: 'app_data_json',
        );
        PdfAnnotationSaveDiagnostics.log(
          saveOperationId,
          'app_data_write',
          duration: appDataTimer.elapsed,
          fields: {'bytes': payloadBytes.length, 'status': 'success'},
        );
      } catch (error) {
        PdfAnnotationSaveDiagnostics.log(
          saveOperationId,
          'app_data_write',
          duration: appDataTimer.elapsed,
          fields: {
            'bytes': payloadBytes.length,
            'status': 'error',
            'errorType': error.runtimeType,
          },
        );
        rethrow;
      }

      // Also update sidecar file next to PDF if directory is writable
      var sidecarStatus = 'not_applicable';
      if (filePath != null && filePath.isNotEmpty) {
        sidecarStatus = 'success';
        final sidecarTimer = Stopwatch()..start();
        PdfAnnotationSaveDiagnostics.log(
          saveOperationId,
          'sidecar_prepare',
          duration: Duration.zero,
          fields: {
            'bytes': payloadBytes.length,
            'serialization': 'reused_app_data_json',
          },
        );
        try {
          final sidecar = File('$filePath.hlann');
          await _writeAtomically(
            sidecar,
            payloadBytes,
            operationId: saveOperationId,
            destination: 'pdf_sidecar',
          );
          PdfAnnotationSaveDiagnostics.log(
            saveOperationId,
            'sidecar_write',
            duration: sidecarTimer.elapsed,
            fields: {'bytes': payloadBytes.length, 'status': 'success'},
          );
        } catch (error) {
          // Non-critical if user PDF folder is read-only
          sidecarStatus = 'failed_noncritical';
          PdfAnnotationSaveDiagnostics.log(
            saveOperationId,
            'sidecar_write',
            duration: sidecarTimer.elapsed,
            fields: {
              'bytes': payloadBytes.length,
              'status': 'warning',
              'issue': sidecarStatus,
              'errorType': error.runtimeType,
            },
          );
        }
      }

      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'storage_total',
        duration: totalTimer.elapsed,
        fields: {
          'annotations': annotationCount,
          'payloadBytes': payloadBytes.length,
          'pdfBytes': pdfBytesLength ?? 'unknown',
          'sidecarStatus': sidecarStatus,
          'status': 'success',
        },
      );
      return true;
    } catch (e) {
      FrontendLogger.write(
        '[PdfAnnotationStorageService] saveAnnotations error: ${e.runtimeType}',
      );
      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'storage_total',
        duration: totalTimer.elapsed,
        fields: {'status': 'error', 'errorType': e.runtimeType},
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
    return text.contains('/Highlight') && text.contains('/Subtype /Highlight');
  }

  Future<void> _writeAtomically(
    File target,
    Uint8List contents, {
    required String operationId,
    required String destination,
  }) async {
    final targetPath = target.absolute.path;
    final previousWrite = _pendingWrites[targetPath] ?? Future<void>.value();
    final queueTimer = Stopwatch()..start();
    final write = previousWrite.catchError((Object _) {}).then((_) {
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'atomic_queue_wait',
        duration: queueTimer.elapsed,
        fields: {'destination': destination},
      );
      return _replaceAtomically(
        target,
        contents,
        operationId: operationId,
        destination: destination,
      );
    });
    _pendingWrites[targetPath] = write;
    try {
      await write;
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'atomic_write_total',
        duration: queueTimer.elapsed,
        fields: {
          'destination': destination,
          'bytes': contents.length,
          'status': 'success',
        },
      );
    } catch (error) {
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'atomic_write_total',
        duration: queueTimer.elapsed,
        fields: {
          'destination': destination,
          'bytes': contents.length,
          'status': 'error',
          'errorType': error.runtimeType,
        },
      );
      rethrow;
    } finally {
      if (identical(_pendingWrites[targetPath], write)) {
        _pendingWrites.remove(targetPath);
      }
    }
  }

  Future<void> _replaceAtomically(
    File target,
    Uint8List contents, {
    required String operationId,
    required String destination,
  }) async {
    final temporaryFile = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.${_temporaryFileSequence++}.tmp',
    );
    try {
      final flushTimer = Stopwatch()..start();
      try {
        await temporaryFile.writeAsBytes(contents, flush: true);
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'atomic_write_flush',
          duration: flushTimer.elapsed,
          fields: {
            'destination': destination,
            'bytes': contents.length,
            'status': 'success',
          },
        );
      } catch (error) {
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'atomic_write_flush',
          duration: flushTimer.elapsed,
          fields: {
            'destination': destination,
            'bytes': contents.length,
            'status': 'error',
            'errorType': error.runtimeType,
          },
        );
        rethrow;
      }
      final renameTimer = Stopwatch()..start();
      try {
        await temporaryFile.rename(target.path);
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'atomic_rename',
          duration: renameTimer.elapsed,
          fields: {'destination': destination, 'status': 'success'},
        );
      } catch (error) {
        PdfAnnotationSaveDiagnostics.log(
          operationId,
          'atomic_rename',
          duration: renameTimer.elapsed,
          fields: {
            'destination': destination,
            'status': 'error',
            'errorType': error.runtimeType,
          },
        );
        rethrow;
      }
    } finally {
      final cleanupTimer = Stopwatch()..start();
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'atomic_cleanup',
        duration: cleanupTimer.elapsed,
        fields: {'destination': destination},
      );
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
