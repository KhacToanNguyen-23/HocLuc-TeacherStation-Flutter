import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/services/teacher_notes_privacy.dart';

void main() {
  bool allowed({
    bool sharing = true,
    bool selecting = false,
    bool fresh = true,
    String? title = 'HocLuc Audience session',
    List<Map<String, dynamic>>? sources,
  }) => canShowTeacherNotes(
    sharing: sharing,
    selecting: selecting,
    outputFresh: fresh,
    audienceTitle: title,
    sources:
        sources ??
        [
          {'surface': 'window', 'label': 'HocLuc Audience session'},
        ],
  );
  test('teacher can use notes before sharing but picker always hides them', () {
    expect(allowed(sharing: false), isTrue);
    expect(allowed(sharing: false, selecting: true), isFalse);
    expect(allowed(selecting: true), isFalse);
  });
  test('only matching fresh audience window is safe', () {
    expect(allowed(), isTrue);
    expect(allowed(fresh: false), isFalse);
    expect(allowed(title: null), isFalse);
    expect(allowed(sources: []), isFalse);
    expect(
      allowed(
        sources: [
          {'surface': 'monitor', 'label': 'HocLuc Audience session'},
        ],
      ),
      isFalse,
    );
    expect(
      allowed(
        sources: [
          {'surface': 'window', 'label': 'HocLucStation'},
        ],
      ),
      isFalse,
    );
    expect(
      allowed(
        sources: [
          {'surface': 'window', 'label': 'HocLuc Audience session'},
          {'surface': 'window', 'label': 'HocLucStation'},
        ],
      ),
      isFalse,
    );
  });
}
