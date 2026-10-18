// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

extension StudioStatePluginsAndDocsExt on StudioState {
  void setActiveSubjectTool(String? t) {
    activeSubjectTool = t;
    notifyListeners();
  }

  void toggleChalkAnnotationsVisibility() {
    chalkAnnotationsVisible = !chalkAnnotationsVisible;
    notifyListeners();
  }

  void setSubjectPaletteOffset(Offset offset) {
    subjectPaletteOffset = offset;
    notifyListeners();
  }

  void openPlugin(InstalledPlugin plugin, {bool openModal = false}) {
    if (plugin.manifest.uiPlacement == 'floating_window') {
      floatingPlugin = plugin;
      pluginFloating = true;
      pluginFloatingSize = Size(
        plugin.manifest.uiDefaultWidth,
        plugin.manifest.uiDefaultHeight,
      );
      if (activePlugin == null ||
          activePlugin!.manifest.uiPlacement == 'floating_window') {
        activePlugin = plugin;
      }
    } else {
      activePlugin = plugin;
      showPluginDrawer = openModal;
      if (floatingPlugin == null) {
        pluginFloating = false;
      }
    }
    showQuestionsDrawer = false;
    notifyListeners();
  }

  void closePlugin() {
    if (activePlugin != null &&
        floatingPlugin != null &&
        activePlugin!.id == floatingPlugin!.id) {
      floatingPlugin = null;
      pluginFloating = false;
    } else if (floatingPlugin == null) {
      pluginFloating = false;
    }
    activePlugin = null;
    showPluginDrawer = false;
    activeSubjectTool = null;
    notifyListeners();
  }

  void closeFloatingPlugin() {
    final closingId = floatingPlugin?.id;
    floatingPlugin = null;
    pluginFloating = false;
    if (activePlugin != null &&
        (activePlugin!.id == closingId ||
            activePlugin!.manifest.uiPlacement == 'floating_window')) {
      activePlugin = null;
      showPluginDrawer = false;
      activeSubjectTool = null;
    }
    notifyListeners();
  }

  void togglePluginFloating() {
    pluginFloating = !pluginFloating;
    if (pluginFloating && floatingPlugin == null && activePlugin != null) {
      floatingPlugin = activePlugin;
    } else if (!pluginFloating &&
        floatingPlugin != null &&
        activePlugin?.id == floatingPlugin?.id) {
      floatingPlugin = null;
      showPluginDrawer = true;
    }
    notifyListeners();
  }

  void setPluginFloatingPosition(Offset pos) {
    pluginFloatingPosition = pos;
    notifyListeners();
  }

  void setPluginFloatingSize(Size s) {
    pluginFloatingSize = s;
    notifyListeners();
  }

  List<PdfDgnlPassage> get pdfDgnlPassages => _pdfDgnlPassages;

  List<PdfDgnlPassage> getPdfDgnlPassagesForPage(int pageNumber) =>
      _pdfDgnlPassages
          .where((p) => p.pageNumber == pageNumber && p.isVisible)
          .toList();

  void addPdfDgnlPassage(PdfDgnlPassage passage) {
    _pdfDgnlPassages.removeWhere(
      (p) =>
          p.pageNumber == passage.pageNumber &&
          p.normalizedBounds.overlaps(passage.normalizedBounds),
    );
    _pdfDgnlPassages.add(passage);
    notifyListeners();
  }

  void removePdfDgnlPassage(String id) {
    _pdfDgnlPassages.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void togglePdfDgnlPassageVisibility(String id) {
    for (final p in _pdfDgnlPassages) {
      if (p.id == id) {
        p.isVisible = !p.isVisible;
        break;
      }
    }
    notifyListeners();
  }

  void clearPdfDgnlPassages() {
    _pdfDgnlPassages.clear();
    notifyListeners();
  }

  /// Tự động định vị và tạo Highlight trực tiếp trên đề PDF từ kết quả phân tích DGNL
  Future<void> highlightPdfPassageFromAnalysis(
    String rawText,
    List<Map<String, dynamic>> rawHighlights, {
    Map<String, dynamic> metrics = const {},
  }) async {
    final ctrl = pdfViewerController;
    if (ctrl == null || !ctrl.isReady || ctrl.pages.isEmpty) return;

    final targetPageNum = pdfPage.clamp(1, ctrl.pages.length);
    final page = ctrl.pages[targetPageNum - 1];

    try {
      final pageText = await page.loadText();
      if (pageText == null || pageText.fullText.isEmpty) return;

      final full = pageText.fullText;
      final fullLower = full.toLowerCase();

      final snippetClean = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
      final snippetWords = snippetClean.split(' ');
      final leadPhrase = snippetWords.take(5).join(' ').toLowerCase();

      int passStartIdx = fullLower.indexOf(leadPhrase);
      if (passStartIdx == -1 && snippetWords.isNotEmpty) {
        passStartIdx = fullLower.indexOf(snippetWords.first.toLowerCase());
      }
      passStartIdx = passStartIdx.clamp(0, math.max(0, full.length - 1));

      final passEndIdx = math.min(
        full.length - 1,
        passStartIdx + snippetClean.length,
      );
      final passCharBoxes = <Rect>[];
      for (
        int i = passStartIdx;
        i <= passEndIdx && i < pageText.charRects.length;
        i++
      ) {
        final r = pageText.charRects[i];
        final rFlutter = r.toRect(page: page);
        passCharBoxes.add(
          Rect.fromLTRB(
            (rFlutter.left / page.width).clamp(0.0, 1.0),
            (rFlutter.top / page.height).clamp(0.0, 1.0),
            (rFlutter.right / page.width).clamp(0.0, 1.0),
            (rFlutter.bottom / page.height).clamp(0.0, 1.0),
          ),
        );
      }

      Rect passBounds = const Rect.fromLTWH(0.05, 0.2, 0.9, 0.5);
      if (passCharBoxes.isNotEmpty) {
        double minX = passCharBoxes.first.left;
        double maxX = passCharBoxes.first.right;
        double minY = passCharBoxes.first.top;
        double maxY = passCharBoxes.first.bottom;
        for (final b in passCharBoxes) {
          minX = math.min(minX, b.left);
          maxX = math.max(maxX, b.right);
          minY = math.min(minY, b.top);
          maxY = math.max(maxY, b.bottom);
        }
        passBounds = Rect.fromLTRB(
          (minX - 0.02).clamp(0.0, 1.0),
          (minY - 0.01).clamp(0.0, 1.0),
          (maxX + 0.02).clamp(0.0, 1.0),
          (maxY + 0.01).clamp(0.0, 1.0),
        );
      }

      final spans = <PdfDgnlHighlightSpan>[];
      for (final hl in rawHighlights) {
        final hlText = hl['text']?.toString().trim() ?? '';
        if (hlText.isEmpty) continue;
        final category = hl['category']?.toString() ?? 'grammar';
        final level = hl['level']?.toString() ?? 'B2';
        final type = hl['type']?.toString() ?? category.toUpperCase();
        final note = hl['note']?.toString() ?? '';

        final hlLower = hlText.toLowerCase();
        int sIdx = passStartIdx;
        while ((sIdx = fullLower.indexOf(hlLower, sIdx)) != -1 &&
            sIdx <= passEndIdx + 300) {
          final eIdx = sIdx + hlLower.length;
          final matchedBoxes = <Rect>[];
          for (
            int ci = sIdx;
            ci < eIdx && ci < pageText.charRects.length;
            ci++
          ) {
            final r = pageText.charRects[ci];
            final rFlutter = r.toRect(page: page);
            matchedBoxes.add(
              Rect.fromLTRB(
                (rFlutter.left / page.width).clamp(0.0, 1.0),
                (rFlutter.top / page.height).clamp(0.0, 1.0),
                (rFlutter.right / page.width).clamp(0.0, 1.0),
                (rFlutter.bottom / page.height).clamp(0.0, 1.0),
              ),
            );
          }

          if (matchedBoxes.isNotEmpty) {
            final lines = <List<Rect>>[];
            for (final b in matchedBoxes) {
              bool added = false;
              for (final line in lines) {
                final ref = line.first;
                if ((ref.top - b.top).abs() < 0.015 ||
                    (b.top <= ref.bottom && b.bottom >= ref.top)) {
                  line.add(b);
                  added = true;
                  break;
                }
              }
              if (!added) lines.add([b]);
            }
            final lineRects = <Rect>[];
            for (final line in lines) {
              double lx1 = line.first.left, lx2 = line.first.right;
              double ly1 = line.first.top, ly2 = line.first.bottom;
              for (final r in line) {
                lx1 = math.min(lx1, r.left);
                lx2 = math.max(lx2, r.right);
                ly1 = math.min(ly1, r.top);
                ly2 = math.max(ly2, r.bottom);
              }
              lineRects.add(
                Rect.fromLTRB(
                  lx1,
                  (ly1 - 0.001).clamp(0.0, 1.0),
                  lx2,
                  (ly2 + 0.001).clamp(0.0, 1.0),
                ),
              );
            }

            spans.add(
              PdfDgnlHighlightSpan(
                text: hlText,
                category: category,
                level: level,
                type: type,
                note: note,
                normalizedRects: lineRects,
              ),
            );
          }
          sIdx = eIdx;
        }
      }

      final passage = PdfDgnlPassage(
        id: 'dgnl-${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: targetPageNum.toInt(),
        rawText: snippetClean,
        normalizedBounds: passBounds,
        spans: spans,
        metrics: metrics,
        clozeQuestions: const [],
      );

      addPdfDgnlPassage(passage);
    } catch (e) {
      FrontendLogger.write(
        '[StudioState] highlightPdfPassageFromAnalysis error: $e',
      );
    }
  }

  void startSnipping({String target = 'dgnl'}) {
    _wasFloatingBeforeSnip = pluginFloating;
    showPluginDrawer = false;
    pluginFloating = false;
    isSnippingActive = true;
    snipTarget = target;
    notifyListeners();
  }

  void stopSnipping() {
    isSnippingActive = false;
    showPluginDrawer = false;
    if (_wasFloatingBeforeSnip) {
      pluginFloating = true;
    }
    notifyListeners();
  }

  void sendSnippetToPlugin(String text, {String? target}) {
    final t = target ?? snipTarget;
    stopSnipping();
    final clean = text.trim();
    if (clean.isNotEmpty) {
      if (activePlugin != null && _wasFloatingBeforeSnip) {
        pluginFloating = true;
      }
      onSnippetCapturedForPlugin?.call(clean, t);
      notifyListeners();
    }
  }

  void handlePluginMessage(
    dynamic message, {
    void Function(String jsScript)? executeJs,
    dynamic manifest,
  }) {
    HostBridge.instance.handleMessage(
      rawMessage: message,
      studio: this,
      manifest: manifest ?? activePlugin?.manifest ?? floatingPlugin?.manifest,
      executeJs: executeJs,
    );
  }

  Offset get pdfWindowPosition => _pdfWindowPosition ?? const Offset(0, 0);
  set pdfWindowPosition(Offset pos) => _pdfWindowPosition = pos;

  Size get pdfWindowSize => _pdfWindowSize ?? const Size(540, 720);
  set pdfWindowSize(Size s) => _pdfWindowSize = s;

  bool get pdfWindowMaximized => _pdfWindowMaximized ?? false;
  set pdfWindowMaximized(bool val) => _pdfWindowMaximized = val;

  void setPdfWindowPosition(Offset pos) {
    hasCustomPdfWindowPos = true;
    pdfWindowPosition = pos;
    notifyListeners();
  }

  void setPdfWindowSize(Size s) {
    hasCustomPdfWindowSize = true;
    pdfWindowSize = s;
    notifyListeners();
  }

  void togglePdfWindowMaximized() {
    pdfWindowMaximized = !pdfWindowMaximized;
    notifyListeners();
  }

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

  ImportedDocument? get activeDoc {
    if (activeDocId == null) return null;
    return importedDocs.where((d) => d.id == activeDocId).firstOrNull;
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
    _revision++;
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
    _revision++;
    notifyListeners();
  }

  void closeDocOnBoard() {
    hasCustomPdfWindowSize = false;
    hasCustomPdfWindowPos = false;
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

  void setViewportMode(StudioViewportMode mode) {
    if (viewportMode != mode) {
      viewportMode = mode;
      notifyListeners();
    }
  }
}

