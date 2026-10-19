/// One destination for all teaching entry points. A missing URL means an
/// explicitly requested one-off lesson, never a fallback for a linked class.
class TeachingTarget {
  const TeachingTarget({
    required this.title,
    this.meetingUrl,
    this.courseId,
    this.teacherEmail,
    this.planningId,
  });
  final String title;
  final String? meetingUrl, courseId, teacherEmail, planningId;
  bool get isLinked => courseId != null;
  bool get isOneOff => meetingUrl == null && !isLinked;
}
