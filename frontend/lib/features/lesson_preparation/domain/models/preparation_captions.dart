/// Convert bounded generated SRT into text-track data without interpreting HTML.
String preparationWebVtt(String srt) {
  if (srt.length > 2000000) {
    throw const FormatException('Subtitle file is too large.');
  }
  final normalized = srt.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final timing = RegExp(
    r'^(\d{2}:\d{2}:\d{2}),(\d{3}) --> (\d{2}:\d{2}:\d{2}),(\d{3})$',
    multiLine: true,
  );
  // Escape cue text so teacher-authored angle brackets render as plain text.
  final safe = normalized
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  // Restore only the delimiter produced by the trusted SRT timestamp grammar.
  final restored = safe.replaceAll(' --&gt; ', ' --> ');
  return 'WEBVTT\n\n${restored.replaceAllMapped(timing, (m) => '${m[1]}.${m[2]} --> ${m[3]}.${m[4]}')}';
}
