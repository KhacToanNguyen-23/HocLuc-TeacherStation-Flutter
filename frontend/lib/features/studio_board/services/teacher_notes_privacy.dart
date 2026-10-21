/// Fail closed if the browser cannot identify the exact audience window.
bool canShowTeacherNotes({
  required bool sharing,
  required bool selecting,
  required bool outputFresh,
  required String? audienceTitle,
  required List<Map<String, dynamic>> sources,
}) {
  if (selecting) return false;
  if (!sharing) return true;
  if (!outputFresh || audienceTitle == null || sources.isEmpty) return false;
  return sources.every(
    (source) =>
        source['surface'] == 'window' &&
        (source['label'] as String? ?? '').contains(audienceTitle),
  );
}
