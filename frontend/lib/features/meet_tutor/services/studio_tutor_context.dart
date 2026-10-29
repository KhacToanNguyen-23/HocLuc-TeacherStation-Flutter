import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../../studio_board/domain/models/studio_state.dart';
import '../domain/models/tutor_models.dart';
import 'studio_tutor_pdf_reader.dart'
    if (dart.library.io) 'studio_tutor_pdf_reader_io.dart'
    as reader;

/// Student-facing page context only; never serialize the whole lesson here.
///
/// PDF chalk is deliberately excluded: its page-indexed storage has no document
/// ownership. Ink geometry, Smart Pen answers, drafts, notes and analysis maps
/// are never supplied as textual evidence. PDF text is its embedded page text,
/// not annotation dictionaries or OCR. Only the active document is retained.
class StudioTutorContext extends ChangeNotifier {
  StudioTutorContext(this._studio) {
    _signature = _visibleSignature();
    // Studio forwards child events today; listening directly also supports
    // controller-only edits. The signature deduplicates forwarded events.
    _studio.addListener(_onChanged);
    _studio.canvas.addListener(_onChanged);
    _studio.pdf.addListener(_onChanged);
  }

  static const maxPdfBytes = 25 * 1024 * 1024;
  static const maxPdfPages = 200;
  static const handwritingLimitation =
      'Raw handwriting and image-only PDFs are not recognized; text evidence '
      'requires embedded PDF text or visible sticker/chalk text.';

  final StudioState _studio;
  int _revision = 0;
  int get revision => _revision;
  bool _disposed = false;
  late List<Object?> _signature;
  _DocumentKey? _cachedKey;
  Future<List<String>>? _cachedText;
  // Serialize extraction so rapid switching cannot launch multiple PDF parsers.
  Future<void> _extractionTail = Future<void>.value();

  bool get _boardVisible => _studio.viewportMode != StudioViewportMode.fullPdf;
  bool get _pdfVisible => _studio.viewportMode != StudioViewportMode.fullBoard;

  _DocumentKey? _documentKey() {
    final bytes = _studio.pdfBytes;
    final path = _studio.pdfFilePath;
    if (bytes == null && (path == null || path.isEmpty)) return null;
    return _DocumentKey(
      _studio.activeDocId,
      _studio.activeDoc?.contentFingerprint,
      path,
      bytes,
    );
  }

  List<Object?> _visibleSignature() {
    final signature = <Object?>[_studio.viewportMode, _studio.subject];
    if (_boardVisible) {
      signature.add(_studio.page);
      for (final s in _studio.pageStickers[_studio.page] ?? <BoardSticker>[]) {
        signature.addAll([s.id, s.rawText, s.normalizedRect]);
      }
      signature.add(_studio.chalkAnnotationsVisible);
      if (_studio.chalkAnnotationsVisible) {
        for (final a
            in _studio.pageChalkAnnotations[_studio.page] ??
                <SmartChalkAnnotation>[]) {
          if (a.isVisible) {
            signature.addAll([
              a.id,
              a.rawText,
              a.normalizedBounds,
              a.normalizedOffset,
            ]);
          }
        }
      }
      // Ink changes invalidate an in-flight answer even though ink is not OCR'd.
      // No point-array traversal on each drawing notification.
      for (final s in _studio.canvas.currentStrokes) {
        signature.addAll([
          s,
          s.points.length,
          s.points.firstOrNull,
          s.points.lastOrNull,
          s.color,
          s.width,
          s.rect,
        ]);
      }
    }
    if (_pdfVisible) {
      signature.addAll([_documentKey(), _studio.pdfPage]);
      for (final s in _studio.pdfAnnotationsForPage(_studio.pdfPage)) {
        signature.addAll([
          s,
          s.points.length,
          s.points.firstOrNull,
          s.points.lastOrNull,
          s.color,
          s.width,
          s.rect,
        ]);
      }
    }
    return signature;
  }

  void _onChanged() {
    if (_disposed) return;
    final key = _documentKey();
    if (key != _cachedKey) {
      _cachedKey = null;
      _cachedText = null;
    }
    final signature = _visibleSignature();
    if (listEquals(signature, _signature)) return;
    _signature = signature;
    _revision++;
    notifyListeners();
  }

  /// Returns no evidence when the snapshot changed while extraction was pending.
  /// The old revision lets TutorController reject the result before sending.
  Future<TutorContext> build(String question) async {
    if (_disposed) throw StateError('StudioTutorContext is disposed');
    _onChanged(); // Also observe callers which edited public maps in place.
    final version = revision;
    final page = _pdfVisible ? _studio.pdfPage : _studio.page + 1;
    final key = _pdfVisible ? _documentKey() : null;
    final candidates = <_Chunk>[];
    if (_boardVisible) {
      final boardPage = _studio.page + 1;
      for (final s in _studio.pageStickers[_studio.page] ?? <BoardSticker>[]) {
        _addChunks(
          candidates,
          'board:$boardPage:sticker:${s.id}',
          'Board page $boardPage — sticker',
          s.rawText,
          true,
        );
      }
      if (_studio.chalkAnnotationsVisible) {
        for (final a
            in _studio.pageChalkAnnotations[_studio.page] ??
                <SmartChalkAnnotation>[]) {
          if (a.isVisible) {
            _addChunks(
              candidates,
              'board:$boardPage:chalk:${a.id}',
              'Board page $boardPage — chalk',
              a.rawText,
              true,
            );
          }
        }
      }
    }
    final pdfPage = _studio.pdfPage;
    if (key != null) {
      final pages = await _textFor(key);
      if (!_disposed) _onChanged();
      if (_disposed || version != revision || key != _documentKey()) {
        return TutorContext(
          revision: version,
          lessonSubject: _studio.subject,
          currentPage: page,
          sources: const [],
        );
      }
      for (var i = 0; i < pages.length; i++) {
        _addChunks(
          candidates,
          'pdf:${key.id ?? 'active'}:${i + 1}',
          'PDF page ${i + 1}',
          pages[i],
          i + 1 == pdfPage,
        );
      }
    }
    final terms = _terms(question);
    final ranked = candidates
        .map((c) => (c, _score(c.text, terms)))
        .where((entry) => entry.$1.current || entry.$2 > 0)
        .toList();
    ranked.sort((a, b) {
      final current = (b.$1.current ? 1 : 0) - (a.$1.current ? 1 : 0);
      if (current != 0) return current;
      final relevance = b.$2.compareTo(a.$2);
      return relevance != 0 ? relevance : a.$1.order.compareTo(b.$1.order);
    });
    return TutorContext(
      revision: version,
      lessonSubject: _studio.subject,
      currentPage: page,
      sources: List.unmodifiable(
        ranked
            .take(6)
            .map(
              (entry) => TutorSource(
                id: entry.$1.id,
                label: entry.$1.label,
                text: entry.$1.text,
              ),
            ),
      ),
    );
  }

  Future<List<String>> _textFor(_DocumentKey key) {
    if (key == _cachedKey && _cachedText != null) return _cachedText!;
    _cachedKey = key;
    final task = _extractionTail.then((_) async {
      if (_disposed || key != _documentKey()) return <String>[];
      try {
        final bytes =
            key.bytes ??
            (key.path == null
                ? null
                : await reader.readTutorPdf(key.path!, maxPdfBytes));
        if (_disposed ||
            key != _documentKey() ||
            bytes == null ||
            bytes.lengthInBytes > maxPdfBytes ||
            bytes.isEmpty) {
          return <String>[];
        }
        final text = await compute(_extractPdfText, bytes);
        return !_disposed && key == _documentKey() ? text : <String>[];
      } catch (_) {
        // Missing files, malformed/encrypted PDFs and extraction failures yield
        // board-only context, never fabricated evidence.
        return <String>[];
      }
    });
    _cachedText = task;
    _extractionTail = task.then<void>((_) {});
    return task;
  }

  @override
  void dispose() {
    _disposed = true;
    _studio.removeListener(_onChanged);
    _studio.canvas.removeListener(_onChanged);
    _studio.pdf.removeListener(_onChanged);
    _cachedKey = null;
    _cachedText = null;
    super.dispose();
  }
}

class _DocumentKey {
  const _DocumentKey(this.id, this.fingerprint, this.path, this.bytes);
  final String? id;
  final String? fingerprint;
  final String? path;
  final Uint8List? bytes;

  @override
  bool operator ==(Object other) =>
      other is _DocumentKey &&
      id == other.id &&
      fingerprint == other.fingerprint &&
      path == other.path &&
      identical(bytes, other.bytes);
  @override
  int get hashCode =>
      Object.hash(id, fingerprint, path, identityHashCode(bytes));
}

// Pure Dart parser; native compute runs this outside the UI isolate. On web,
// Flutter compute runs on the current event loop. Retained text is bounded too.
List<String> _extractPdfText(Uint8List bytes) {
  if (bytes.lengthInBytes > StudioTutorContext.maxPdfBytes) return [];
  final document = sf.PdfDocument(inputBytes: bytes);
  try {
    if (document.pages.count > StudioTutorContext.maxPdfPages) return [];
    final extractor = sf.PdfTextExtractor(document);
    final pages = <String>[];
    for (var i = 0; i < document.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      // Retain every page (including a late current page), at most two million
      // characters total. Long pages are truncated rather than evicting pages.
      final length = text.length.clamp(0, 10000);
      pages.add(text.substring(0, length));
    }
    return pages;
  } finally {
    document.dispose();
  }
}

class _Chunk {
  const _Chunk(this.id, this.label, this.text, this.current, this.order);
  final String id;
  final String label;
  final String text;
  final bool current;
  final int order;
}

void _addChunks(
  List<_Chunk> out,
  String id,
  String label,
  String text,
  bool current,
) {
  final clean = text.trim();
  // Never sever a sentence: a suffix could otherwise lose its negation and
  // masquerade as a complete statement when validated against the chunk.
  var chunk = '';
  var sequence = 0;
  void flush() {
    if (chunk.isEmpty) return;
    out.add(
      _Chunk('$id:chunk:${sequence++}', label, chunk, current, out.length),
    );
    chunk = '';
  }

  for (final sentence in clean.split(RegExp(r'(?<=[.!?。！？])\s+'))) {
    if (sentence.length > 3000) {
      flush();
      continue;
    }
    if (chunk.length + sentence.length + 1 > 3000) flush();
    chunk = chunk.isEmpty ? sentence : '$chunk\n$sentence';
  }
  flush();
}

final _word = RegExp(r'[\p{L}\p{N}]+', unicode: true);
const _stopWords = {
  'the',
  'a',
  'an',
  'is',
  'are',
  'what',
  'why',
  'how',
  'this',
  'that',
  'of',
  'to',
  'in',
  'and',
  'là',
  'gì',
  'và',
  'của',
  'tại',
  'sao',
};
Set<String> _terms(String text) => _word
    .allMatches(text.toLowerCase())
    .map((m) => m.group(0)!)
    .where((t) => !_stopWords.contains(t))
    .toSet();
int _score(String text, Set<String> terms) =>
    _terms(text).intersection(terms).length;
