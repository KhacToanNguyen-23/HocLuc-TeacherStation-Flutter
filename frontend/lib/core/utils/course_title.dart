final _courseTitleWhitespace = RegExp(
  r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+',
);

String normalizeCourseTitle(String title) =>
    title.replaceAll(_courseTitleWhitespace, ' ').trim().toLowerCase();
