// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

String _newPageId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';

extension StudioStatePresenter on StudioState {
  String boardSaveFingerprint(Map<String, dynamic> content) {
    final comparison = Map<String, dynamic>.of(content)
      ..remove('boardRevision')
      ..remove('expectedPreparationRevision');
    return jsonEncode(comparison);
  }

  void acknowledgeBoardSave(
    Map<String, dynamic> snapshot, {
    required bool unchanged,
  }) {
    boardRevision =
        (snapshot['boardRevision'] as num?)?.toInt() ?? boardRevision;
    if (snapshot.containsKey('teacherCueUpdates')) {
      preparationDocument?['revision'] =
          ((snapshot['expectedPreparationRevision'] as num?)?.toInt() ?? 0) + 1;
      final sameCues =
          jsonEncode(preparationDocument?['teacherCues']) ==
          jsonEncode(snapshot['teacherCueUpdates']);
      if (unchanged || sameCues) teacherCuesEdited = false;
    }
  }

  /// Stable identities travel with pages; legacy index notes retain their order.
  void ensurePageIds() {
    if (pages.isEmpty) pages.add([]);
    final seen = <String>{};
    pageIds = List.generate(pages.length, (i) {
      final candidate = i < pageIds.length ? pageIds[i] : '';
      final id = candidate.isNotEmpty && !seen.contains(candidate)
          ? candidate
          : _newPageId();
      seen.add(id);
      return id;
    });
  }

  void movePage(int from, int to) {
    if (from < 0 ||
        to < 0 ||
        from >= pages.length ||
        to >= pages.length ||
        from == to) {
      return;
    }
    ensurePageIds();
    final selectedId = pageIds[page.clamp(0, pageIds.length - 1)];
    final order = List.generate(pages.length, (i) => i);
    order.insert(to, order.removeAt(from));
    final oldPages = List.of(pages);
    final oldIds = List.of(pageIds);
    final oldTitles = List.of(pageTitles);
    final oldNotes = List.of(pageNotes);
    pages = order.map((i) => oldPages[i]).toList();
    pageIds = order.map((i) => oldIds[i]).toList();
    pageTitles = order
        .map((i) => i < oldTitles.length ? oldTitles[i] : 'Trang ${i + 1}')
        .toList();
    pageNotes = order
        .map((i) => i < oldNotes.length ? oldNotes[i] : '')
        .toList();
    void remap<T>(Map<int, List<T>> entries) {
      final old = Map<int, List<T>>.of(entries);
      entries.clear();
      for (var i = 0; i < order.length; i++) {
        if (old.containsKey(order[i])) entries[i] = old[order[i]]!;
      }
    }

    remap(pageStickers);
    remap(pageChalkAnnotations);
    if (_redoPages != null) remap(_redoPages!);
    _page = pageIds.indexOf(selectedId);
    bumpRevision();
  }

  Map<String, dynamic> get activeTeacherTarget {
    final doc = activeDoc;
    if (viewportMode != StudioViewportMode.fullBoard &&
        doc != null &&
        (pdfFilePath != null || pdfBytes != null)) {
      return {
        'kind': 'pdf',
        'documentId': doc.id,
        'contentFingerprint': doc.contentFingerprint,
        'pageIndex': pdfPage,
      };
    }
    ensurePageIds();
    return {
      'kind': 'board',
      'pageId': pageIds[page.clamp(0, pageIds.length - 1)],
    };
  }

  Map<String, dynamic> get teacherTarget =>
      _pinnedTeacherTarget ?? activeTeacherTarget;
  bool get teacherNotesPinned => _pinnedTeacherTarget != null;
  void pinTeacherNotes() {
    _pinnedTeacherActivityId = activeTeacherActivity?['id']?.toString();
    _pinnedTeacherTarget = Map.of(activeTeacherTarget);
    notifyListeners();
  }

  void followTeacherNotes() {
    _pinnedTeacherTarget = null;
    _pinnedTeacherActivityId = null;
    notifyListeners();
  }

  List<Map<String, dynamic>> get teacherActivities {
    final sections = preparationDocument?['sections'];
    return sections is List
        ? sections
              .whereType<Map>()
              .map((s) => Map<String, dynamic>.from(s))
              .toList()
        : [];
  }

  Map<String, dynamic>? get activeTeacherActivity {
    final matches = teacherActivities.where((s) {
      final targets = s['presentationTargets'] is List
          ? s['presentationTargets'] as List
          : [s['presentationTarget']];
      return targets.whereType<Map>().any(
        (target) => _sameTarget(target, activeTeacherTarget),
      );
    }).toList();
    if (presentedActivityId != null) {
      final explicit = teacherActivities
          .where((s) => s['id'] == presentedActivityId)
          .firstOrNull;
      if (explicit != null &&
          ((explicit['presentationTarget'] == null &&
                  explicit['presentationTargets'] == null) ||
              matches.any((s) => s['id'] == presentedActivityId))) {
        return explicit;
      }
    }
    // A shared page is ambiguous until the teacher chooses its activity.
    return matches.length == 1 ? matches.first : null;
  }

  Map<String, dynamic>? get teacherActivity => teacherNotesPinned
      ? teacherActivities
            .where((s) => s['id'] == _pinnedTeacherActivityId)
            .firstOrNull
      : activeTeacherActivity;

  String? get teacherActivityId => teacherActivity?['id']?.toString();

  bool stepPresentedActivity(int direction) {
    final activities = teacherActivities;
    final current = activities.indexWhere(
      (s) => s['id'] == activeTeacherActivity?['id'],
    );
    final next = current < 0 ? 0 : current + direction;
    return next >= 0 &&
        next < activities.length &&
        presentActivity(activities[next]['id']?.toString());
  }

  bool presentActivity(String? id) {
    final activity = teacherActivities.where((s) => s['id'] == id).firstOrNull;
    if (activity == null) return false;
    final target = activity['presentationTarget'];
    if (target is Map) {
      if (target['kind'] == 'board') {
        ensurePageIds();
        final index = pageIds.indexOf(target['pageId']?.toString() ?? '');
        if (index < 0) return false;
        viewportMode = StudioViewportMode.fullBoard;
        setPage(index);
      } else if (target['kind'] == 'pdf') {
        final doc = importedDocs
            .where(
              (d) =>
                  d.id == target['documentId'] &&
                  d.contentFingerprint != null &&
                  d.contentFingerprint == target['contentFingerprint'],
            )
            .firstOrNull;
        if (doc == null || (doc.path == null && doc.bytes == null)) {
          return false;
        }
        selectDoc(doc.id, targetMode: StudioViewportMode.fullPdf);
        setPdfPage((target['pageIndex'] as num?)?.toInt() ?? 1);
      } else {
        return false;
      }
    }
    presentedActivityId = id;
    notifyListeners();
    return true;
  }

  bool _sameTarget(Map a, Map b) {
    if (a['kind'] != b['kind']) return false;
    if (a['kind'] == 'board') return a['pageId'] == b['pageId'];
    // A replacement PDF never inherits cues merely because its page is equal.
    return a['documentId'] == b['documentId'] &&
        a['contentFingerprint'] != null &&
        a['contentFingerprint'] == b['contentFingerprint'] &&
        a['pageIndex'] == b['pageIndex'];
  }

  Map<String, dynamic>? get currentTeacherCue {
    final target = teacherTarget;
    final cues = preparationDocument?['teacherCues'];
    if (cues is! List) return null;
    Map<String, dynamic>? global;
    for (final value in cues) {
      if (value is! Map ||
          value['locator'] is! Map ||
          !_sameTarget(value['locator'] as Map, target)) {
        continue;
      }
      final activityId = value['activityId']?.toString();
      if (activityId != null && activityId == teacherActivityId) {
        return Map<String, dynamic>.from(value);
      }
      if (activityId == null || activityId.isEmpty) {
        global = Map<String, dynamic>.from(value);
      }
    }
    return global;
  }

  String get teacherNoteText {
    final cue = currentTeacherCue;
    if (cue != null) return cue['text']?.toString() ?? '';
    final target = teacherTarget;
    if (target['kind'] == 'board') {
      final index = pageIds.indexOf(target['pageId'].toString());
      return index >= 0 && index < pageNotes.length ? pageNotes[index] : '';
    }
    return '';
  }

  String get teacherActivityNote =>
      teacherActivity?['teacherNotes']?.toString() ?? '';

  String get teacherTargetLabel {
    final target = teacherTarget;
    if (target['kind'] == 'pdf') {
      final doc = importedDocs
          .where((d) => d.id == target['documentId'])
          .firstOrNull;
      return '${doc?.name ?? 'Tài liệu'} · Trang ${target['pageIndex']}';
    }
    final index = pageIds.indexOf(target['pageId'].toString());
    return index >= 0 ? 'Bảng · Trang ${index + 1}' : 'Trang đã bị xóa';
  }

  void setTeacherNote(String text) {
    final target = teacherTarget;
    if (target['kind'] == 'board' && teacherActivityId == null) {
      final index = pageIds.indexOf(target['pageId'].toString());
      if (index < 0) return;
      setPageNote(index, text);
    }
    preparationDocument ??= {'schemaVersion': 1, 'sections': [], 'scenes': []};
    final raw = preparationDocument!['teacherCues'];
    final cues = raw is List ? List<dynamic>.of(raw) : <dynamic>[];
    final index = cues.indexWhere(
      (v) =>
          v is Map &&
          v['locator'] is Map &&
          _sameTarget(v['locator'] as Map, target) &&
          v['activityId']?.toString() == teacherActivityId,
    );
    final cue = {
      'id': index < 0 ? _newPageId() : (cues[index] as Map)['id'],
      'locator': Map.of(target),
      'text': text,
      if (teacherActivityId != null) 'activityId': teacherActivityId,
    };
    if (index < 0) {
      cues.add(cue);
    } else {
      cues[index] = cue;
    }
    preparationDocument!['teacherCues'] = cues;
    teacherCuesEdited = true;
    bumpRevision();
  }
}
