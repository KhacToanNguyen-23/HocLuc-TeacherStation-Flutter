part of 'studio_state.dart';

/// Page edits are persisted changes; notify only after dirty is set.
extension StudioStateBoardPagesExt on StudioState {
  void clearBoard([int? p]) {
    final index = p ?? page;
    if (index < 0 || index >= pages.length) return;
    dirty = true;
    canvas.clearPage(index);
  }

  void clearPageStrokes([int? p]) {
    final index = p ?? page;
    if (index < 0 || index >= pages.length) return;
    dirty = true;
    canvas.clearPageStrokes(index);
  }

  void addPage([String? title]) {
    dirty = true;
    canvas.addPage(title);
  }

  void deletePage(int index) {
    if (index < 0 || index >= pages.length) return;
    dirty = true;
    canvas.deletePage(index);
  }

  void renamePage(int index, String newTitle) {
    if (index < 0 || index >= pageTitles.length) return;
    dirty = true;
    canvas.renamePage(index, newTitle);
  }

  void clearPage() => clearBoard();

  void setPageNote(int index, String note) {
    if (index < 0 || (index < pageNotes.length && pageNotes[index] == note)) {
      return;
    }
    dirty = true;
    canvas.setPageNote(index, note);
  }
}
