import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/text_profile_models.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_profiler.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/lemmatization_engine.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_tokenizer.dart';

void main() {
  group('1. LemmatizationEngine Unit Tests', () {
    test('normalizeApostrophes normalizes all Unicode apostrophe variants', () {
      expect(LemmatizationEngine.normalizeApostrophes("children’s"), equals("children's"));
      expect(LemmatizationEngine.normalizeApostrophes("studentsʼ"), equals("students'"));
      expect(LemmatizationEngine.normalizeApostrophes("teacher`s"), equals("teacher's"));
      expect(LemmatizationEngine.normalizeApostrophes("they´re"), equals("they're"));
    });

    test('isPossessive correctly identifies singular, plural, and curly possessives', () {
      expect(LemmatizationEngine.isPossessive("teacher's"), isTrue);
      expect(LemmatizationEngine.isPossessive("students'"), isTrue);
      expect(LemmatizationEngine.isPossessive("children’s"), isTrue);
      expect(LemmatizationEngine.isPossessive("teachers’"), isTrue);
      expect(LemmatizationEngine.isPossessive("James'"), isTrue);
      expect(LemmatizationEngine.isPossessive("teachers"), isFalse);
      expect(LemmatizationEngine.isPossessive("student"), isFalse);
    });

    test('stripPossessive returns clean base tokens for all possessive types', () {
      expect(LemmatizationEngine.stripPossessive("teacher's"), equals("teacher"));
      expect(LemmatizationEngine.stripPossessive("student's"), equals("student"));
      expect(LemmatizationEngine.stripPossessive("children's"), equals("children"));
      expect(LemmatizationEngine.stripPossessive("children’s"), equals("children"));
      expect(LemmatizationEngine.stripPossessive("students'"), equals("students"));
      expect(LemmatizationEngine.stripPossessive("students’"), equals("students"));
      expect(LemmatizationEngine.stripPossessive("teachers'"), equals("teachers"));
      expect(LemmatizationEngine.stripPossessive("James'"), equals("James"));
      expect(LemmatizationEngine.stripPossessive("cat"), isNull);
    });

    test('stripClitic cleanly extracts base token from clitic contractions', () {
      expect(LemmatizationEngine.stripClitic("people've"), equals("people"));
      expect(LemmatizationEngine.stripClitic("students'll"), equals("students"));
      expect(LemmatizationEngine.stripClitic("kids're"), equals("kids"));
      expect(LemmatizationEngine.stripClitic("who'd"), equals("who"));
      expect(LemmatizationEngine.stripClitic("didn't"), equals("did"));
      expect(LemmatizationEngine.stripClitic("won't"), equals("will"));
      expect(LemmatizationEngine.stripClitic("can't"), equals("can"));
    });
  });

  group('2. Possessive Suffix Stripping & Fallback in CefrDictionaryData', () {
    test('Resolves singular possessives to base lemma and CEFR level', () {
      final teacherLexeme = CefrDictionaryData.lookupLexeme("teacher's");
      expect(teacherLexeme, isNotNull);
      expect(teacherLexeme!.headword, equals("teacher"));
      expect(teacherLexeme.cefrLevel, equals("A1"));

      final doctorLexeme = CefrDictionaryData.lookupLexeme("doctor's");
      expect(doctorLexeme, isNotNull);
      expect(doctorLexeme!.headword, equals("doctor"));
      expect(doctorLexeme.cefrLevel, equals("A1"));
    });

    test('Resolves plural possessives (s\') through inflection fallback into base singular', () {
      // students' -> students -> student (A1)
      final studentsLexeme = CefrDictionaryData.lookupLexeme("students'");
      expect(studentsLexeme, isNotNull);
      expect(studentsLexeme!.headword, equals("student"));
      expect(studentsLexeme.cefrLevel, equals("A1"));

      // teachers' -> teachers -> teacher (A1)
      final teachersLexeme = CefrDictionaryData.lookupLexeme("teachers'");
      expect(teachersLexeme, isNotNull);
      expect(teachersLexeme!.headword, equals("teacher"));
      expect(teachersLexeme.cefrLevel, equals("A1"));

      // parents' -> parents -> parent (A1)
      final parentsLexeme = CefrDictionaryData.lookupLexeme("parents'");
      expect(parentsLexeme, isNotNull);
      expect(parentsLexeme!.headword, equals("parent"));
      expect(parentsLexeme.cefrLevel, equals("A1"));
    });

    test('Resolves irregular plural possessives (children\'s, men\'s, women\'s)', () {
      // children's -> children -> child (A1)
      final childrenLexeme = CefrDictionaryData.lookupLexeme("children's");
      expect(childrenLexeme, isNotNull);
      expect(childrenLexeme!.headword, equals("child"));
      expect(childrenLexeme.cefrLevel, equals("A1"));

      // men's -> men -> man (A1)
      final menLexeme = CefrDictionaryData.lookupLexeme("men's");
      expect(menLexeme, isNotNull);
      expect(menLexeme!.headword, equals("man"));
      expect(menLexeme.cefrLevel, equals("A1"));

      // women's -> women -> woman (A1)
      final womenLexeme = CefrDictionaryData.lookupLexeme("women's");
      expect(womenLexeme, isNotNull);
      expect(womenLexeme!.headword, equals("woman"));
      expect(womenLexeme.cefrLevel, equals("A1"));

      // people's -> people / person (A1)
      final peopleLexeme = CefrDictionaryData.lookupLexeme("people's");
      expect(peopleLexeme, isNotNull);
      expect(peopleLexeme!.headword, anyOf(equals("person"), equals("people")));
      expect(peopleLexeme.cefrLevel, equals("A1"));
    });

    test('Handles Unicode curly apostrophes seamlessly (children’s, students’)', () {
      final childrenCurly = CefrDictionaryData.lookupLexeme("children’s");
      expect(childrenCurly, isNotNull);
      expect(childrenCurly!.headword, equals("child"));
      expect(childrenCurly.cefrLevel, equals("A1"));

      final studentsCurly = CefrDictionaryData.lookupLexeme("students’");
      expect(studentsCurly, isNotNull);
      expect(studentsCurly!.headword, equals("student"));
      expect(studentsCurly.cefrLevel, equals("A1"));

      final teacherCurly = CefrDictionaryData.lookupLexeme("teacher’s");
      expect(teacherCurly, isNotNull);
      expect(teacherCurly!.headword, equals("teacher"));
      expect(teacherCurly.cefrLevel, equals("A1"));
    });
  });

  group('3. Contractions & Clitics Handling', () {
    test('Resolves negative contractions with correct verb lemma and POS', () {
      final didnLexeme = CefrDictionaryData.lookupLexeme("didn't");
      expect(didnLexeme, isNotNull);
      expect(didnLexeme!.headword, equals("do"));
      expect(didnLexeme.cefrLevel, equals("A1"));
      expect(didnLexeme.defaultPos, equals("VERB"));

      final dontLexeme = CefrDictionaryData.lookupLexeme("don't");
      expect(dontLexeme, isNotNull);
      expect(dontLexeme!.headword, equals("do"));
      expect(dontLexeme.cefrLevel, equals("A1"));

      final isntLexeme = CefrDictionaryData.lookupLexeme("isn't");
      expect(isntLexeme, isNotNull);
      expect(isntLexeme!.headword, equals("be"));
      expect(isntLexeme.cefrLevel, equals("A1"));

      final cantLexeme = CefrDictionaryData.lookupLexeme("can't");
      expect(cantLexeme, isNotNull);
      expect(cantLexeme!.headword, equals("can"));
      expect(cantLexeme.cefrLevel, equals("A1"));

      final wontLexeme = CefrDictionaryData.lookupLexeme("won't");
      expect(wontLexeme, isNotNull);
      expect(wontLexeme!.headword, equals("will"));
      expect(wontLexeme.cefrLevel, equals("A1"));
    });

    test('Resolves pronoun + clitic contractions with correct pronoun lemma and POS', () {
      final theyRe = CefrDictionaryData.lookupLexeme("they're");
      expect(theyRe, isNotNull);
      expect(theyRe!.headword, equals("they"));
      expect(theyRe.cefrLevel, equals("A1"));
      expect(theyRe.defaultPos, equals("PRON"));

      final weVe = CefrDictionaryData.lookupLexeme("we've");
      expect(weVe, isNotNull);
      expect(weVe!.headword, equals("we"));
      expect(weVe.cefrLevel, equals("A1"));
      expect(weVe.defaultPos, equals("PRON"));

      final itS = CefrDictionaryData.lookupLexeme("it's");
      expect(itS, isNotNull);
      expect(itS!.headword, equals("it"));
      expect(itS.cefrLevel, equals("A1"));

      final thatS = CefrDictionaryData.lookupLexeme("that's");
      expect(thatS, isNotNull);
      expect(thatS!.headword, equals("that"));
      expect(thatS.cefrLevel, equals("A1"));

      final youLl = CefrDictionaryData.lookupLexeme("you'll");
      expect(youLl, isNotNull);
      expect(youLl!.headword, equals("you"));
      expect(youLl.cefrLevel, equals("A1"));
    });

    test('Supports clitic stripping fallback for complex tokens (people\'ve)', () {
      final peopleVe = CefrDictionaryData.lookupLexeme("people've");
      expect(peopleVe, isNotNull);
      expect(peopleVe!.headword, anyOf(equals("person"), equals("people")));
      expect(peopleVe.cefrLevel, equals("A1"));
    });
  });

  group('4. TextTokenizer Token Extraction with Possessives & Quotes', () {
    test('extractWordSpans retains trailing apostrophe on possessives while stripping quote delimiters', () {
      const text = "He said 'hello' to the students' teacher and took the children's books.";
      final spans = TextTokenizer.extractWordSpans(text);
      final surfaces = spans.map((s) => s.surface).toList();

      expect(surfaces, contains('hello'));
      expect(surfaces, isNot(contains("hello'")));
      expect(surfaces, contains("students'"));
      expect(surfaces, contains("children's"));
      expect(surfaces, contains("teacher"));
      expect(surfaces, contains("books"));
    });

    test('normalizeLemma properly handles possessive forms to root lemma', () {
      expect(TextTokenizer.normalizeLemma("children's"), equals("child"));
      expect(TextTokenizer.normalizeLemma("children’s"), equals("child"));
      expect(TextTokenizer.normalizeLemma("students'"), equals("student"));
      expect(TextTokenizer.normalizeLemma("students’"), equals("student"));
      expect(TextTokenizer.normalizeLemma("men's"), equals("man"));
      expect(TextTokenizer.normalizeLemma("women's"), equals("woman"));
      expect(TextTokenizer.normalizeLemma("people's"), equals("person"));
    });
  });

  group('5. Full CefrProfiler Passage Verification (Zero False Unknowns)', () {
    test('Passage with possessives, plural possessives, and contractions classifies 100% cleanly', () {
      const text =
          "The children's toys and students' books weren't damaged because they're safe in the teacher's classroom.";
      final rawSpans = TextTokenizer.extractWordSpans(text);
      final profile = CefrProfiler.profileTokens(text, rawSpans);

      final tokenMap = {for (final t in profile.tokens) t.surface: t};

      // 1. children's
      final childrenToken = tokenMap["children's"]!;
      expect(childrenToken.lemma, equals("child"));
      expect(childrenToken.cefrLevel, equals("A1"));
      expect(childrenToken.lexicalStatus, equals(LexicalStatus.graded));

      // 2. students'
      final studentsToken = tokenMap["students'"]!;
      expect(studentsToken.lemma, equals("student"));
      expect(studentsToken.cefrLevel, equals("A1"));
      expect(studentsToken.lexicalStatus, equals(LexicalStatus.graded));

      // 3. weren't
      final werentToken = tokenMap["weren't"]!;
      expect(werentToken.lemma, equals("be"));
      expect(werentToken.cefrLevel, equals("A1"));
      expect(werentToken.pos, equals("VERB"));

      // 4. they're
      final theyreToken = tokenMap["they're"]!;
      expect(theyreToken.lemma, equals("they"));
      expect(theyreToken.cefrLevel, equals("A1"));
      expect(theyreToken.pos, equals("PRON"));

      // 5. teacher's
      final teacherToken = tokenMap["teacher's"]!;
      expect(teacherToken.lemma, equals("teacher"));
      expect(teacherToken.cefrLevel, equals("A1"));
      expect(teacherToken.lexicalStatus, equals(LexicalStatus.graded));

      // Overall check: ZERO words marked as Unknown!
      final unknownTokens = profile.tokens.where((t) => t.cefrLevel == 'Unknown');
      expect(unknownTokens, isEmpty);
    });
  });
}
