import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../board_stroke.dart';
import '../imported_document.dart';
import 'studio_canvas_mixin.dart';

enum StudioViewportMode { fullBoard, fullPdf, split }

/// Mixin quản lý cấu hình Viewport (Toàn bảng, Toàn PDF, Chia đôi màn hình)
/// và danh mục tài liệu PDF đã nhập cùng nét vẽ ghi chú trên từng trang PDF
mixin StudioStageMixin on StudioCanvasMixin {
  StudioViewportMode viewportMode = StudioViewportMode.fullBoard;
  bool pdfOnRight = false;
  double splitRatio = 0.5;

  final List<ImportedDocument> importedDocs = [];
  String? activeDocId;
  String? pdfFilePath;
  Uint8List? pdfBytes;
  int pdfPage = 1;
  int pdfTotalPages = 1;
  Map<int, List<BoardStroke>> pdfAnnotations = {};

  ImportedDocument? get activeDoc {
    if (activeDocId == null) return null;
    return importedDocs.where((d) => d.id == activeDocId).firstOrNull;
  }

  List<BoardStroke> get currentPdfStrokes =>
      pdfAnnotations.putIfAbsent(pdfPage, () => []);

  void togglePdfPosition() {
    pdfOnRight = !pdfOnRight;
    notifyListeners();
  }

  void setPdfOnRight(bool onRight) {
    if (pdfOnRight != onRight) {
      pdfOnRight = onRight;
      notifyListeners();
    }
  }

  void setSplitRatio(double ratio) {
    final clamped = ratio.clamp(0.2, 0.8);
    if ((splitRatio - clamped).abs() > 0.002) {
      splitRatio = clamped;
      notifyListeners();
    }
  }

  void setViewportMode(StudioViewportMode mode) {
    if (viewportMode != mode) {
      viewportMode = mode;
      notifyListeners();
    }
  }

  void addImportedDoc(String name, String? path, Uint8List? bytes) {
    final existing = importedDocs
        .where((d) => d.name == name || (path != null && d.path == path))
        .firstOrNull;
    if (existing != null) {
      selectDoc(existing.id);
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final doc = ImportedDocument(id: id, name: name, path: path, bytes: bytes);
    importedDocs.add(doc);
    selectDoc(id);
  }

  void selectDoc(String id, {StudioViewportMode? targetMode}) {
    final doc = importedDocs.where((d) => d.id == id).firstOrNull;
    if (doc == null) return;

    if (activeDoc != null && activeDoc!.id != id) {
      activeDoc!.annotations.clear();
      activeDoc!.annotations.addAll(pdfAnnotations);
      activeDoc!.totalPages = pdfTotalPages;
    }

    activeDocId = id;
    pdfFilePath = doc.path;
    pdfBytes = doc.bytes;
    pdfPage = 1;
    pdfTotalPages = doc.totalPages > 0 ? doc.totalPages : 1;
    pdfAnnotations.clear();
    pdfAnnotations.addAll(doc.annotations);

    if (targetMode != null) {
      viewportMode = targetMode;
    } else if (viewportMode == StudioViewportMode.fullBoard) {
      viewportMode = StudioViewportMode.split;
    }
    dirty = true;
    revision++;
    notifyListeners();
  }

  void removeDoc(String id) {
    final index = importedDocs.indexWhere((d) => d.id == id);
    if (index == -1) return;
    importedDocs.removeAt(index);
    if (activeDocId == id) {
      if (importedDocs.isNotEmpty) {
        selectDoc(importedDocs.last.id);
      } else {
        activeDocId = null;
        setPdfFile(null, null);
        viewportMode = StudioViewportMode.fullBoard;
      }
    }
    dirty = true;
    revision++;
    notifyListeners();
  }

  void closeDocOnBoard() {
    if (viewportMode != StudioViewportMode.fullBoard) {
      viewportMode = StudioViewportMode.fullBoard;
      notifyListeners();
    }
  }

  Future<void> importPdfDialog() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final name = file.name;
          addImportedDoc(name, file.path, bytes);
        }
        setViewportMode(StudioViewportMode.split);
      }
    } catch (_) {}
  }

  void setPdfFile(String? path, [Uint8List? bytes]) {
    pdfFilePath = path;
    pdfBytes = bytes;
    pdfPage = 1;
    pdfTotalPages = 1;
    pdfAnnotations.clear();
    if (path != null || bytes != null) {
      final name = path != null
          ? path.split(RegExp(r'[\\/]')).last
          : 'Tài liệu.pdf';
      final existing = importedDocs.where((d) => d.name == name).firstOrNull;
      if (existing == null) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final doc = ImportedDocument(
          id: id,
          name: name,
          path: path,
          bytes: bytes,
        );
        importedDocs.add(doc);
        activeDocId = id;
      } else {
        activeDocId = existing.id;
      }
    }
    dirty = true;
    revision++;
    notifyListeners();
  }

  void updatePdfBytesInPlace(Uint8List newBytes) {
    pdfBytes = newBytes;
    dirty = true;
    revision++;
    notifyListeners();
  }

  void setPdfPage(int p) {
    final next = p.clamp(1, pdfTotalPages > 0 ? pdfTotalPages : 1);
    if (next != pdfPage) {
      pdfPage = next;
      notifyListeners();
    }
  }

  void setPdfTotalPages(int total) {
    if (total > 0 && total != pdfTotalPages) {
      pdfTotalPages = total;
      if (activeDoc != null) {
        activeDoc!.totalPages = total;
      }
      notifyListeners();
    }
  }

  void clearPdfPage() {
    pdfAnnotations[pdfPage]?.clear();
    dirty = true;
    revision++;
    notifyListeners();
  }
}
