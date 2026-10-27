import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/dynamic_dictionary_entry.dart';

abstract interface class DictionaryCache {
  Future<DynamicDictionaryEntry?> getEntry(String word);
  Future<void> putEntry(DynamicDictionaryEntry entry);
  Future<DateTime?> getNotFoundUntil(String word);
  Future<void> putNotFoundUntil(String word, DateTime expiresAt);
  Future<void> removeNotFound(String word);
}

/// SharedPreferences-backed per-lemma cache for the small dynamic dictionary.
class SharedPreferencesDictionaryCache implements DictionaryCache {
  SharedPreferencesDictionaryCache({SharedPreferences? preferences})
    : _preferences = preferences == null
          ? null
          : Future<SharedPreferences>.value(preferences);

  static const _entryPrefix = 'cefr_dynamic_dictionary_entry_v1:';
  static const _notFoundPrefix = 'cefr_dynamic_dictionary_404_v1:';

  Future<SharedPreferences>? _preferences;

  Future<SharedPreferences> get _prefs =>
      _preferences ??= SharedPreferences.getInstance();

  @override
  Future<DynamicDictionaryEntry?> getEntry(String word) async {
    try {
      final raw = (await _prefs).getString('$_entryPrefix${_key(word)}');
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DynamicDictionaryEntry.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      // A bad or outdated local record should not prevent an online lookup.
      return null;
    }
  }

  @override
  Future<void> putEntry(DynamicDictionaryEntry entry) async {
    if (entry.source != DictionaryEntrySource.apiCache) return;
    try {
      await (await _prefs).setString(
        '$_entryPrefix${_key(entry.word)}',
        jsonEncode(entry.toJson()),
      );
    } catch (_) {
      // Cache persistence is best effort; a successful lookup is still usable.
    }
  }

  @override
  Future<DateTime?> getNotFoundUntil(String word) async {
    try {
      final raw = (await _prefs).getString('$_notFoundPrefix${_key(word)}');
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putNotFoundUntil(String word, DateTime expiresAt) async {
    try {
      await (await _prefs).setString(
        '$_notFoundPrefix${_key(word)}',
        expiresAt.toIso8601String(),
      );
    } catch (_) {
      // A negative-cache write failure only costs a possible future request.
    }
  }

  @override
  Future<void> removeNotFound(String word) async {
    try {
      await (await _prefs).remove('$_notFoundPrefix${_key(word)}');
    } catch (_) {
      // A stale negative-cache record is ignored by the caller after a hit.
    }
  }

  static String _key(String word) => word.trim().toLowerCase();
}
