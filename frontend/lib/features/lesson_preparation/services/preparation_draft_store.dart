import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recovery copies are addressed by the backend identity, never by display email.
class PreparationDraftStore {
  PreparationDraftStore(String backend, String owner, String plan)
    : key =
          'preparation.recovery.${sha256.convert(utf8.encode(jsonEncode([backend, owner, plan])))}';
  final String key;
  Future<Map<String, dynamic>?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(value) as Map);
    } catch (_) {
      // Preserve unreadable data for diagnosis; never replace the remote lesson.
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> value) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(value),
    );
    if (!saved) throw Exception('Không lưu được bản phục hồi trên máy.');
  }

  Future<void> clear() async {
    final removed = await (await SharedPreferences.getInstance()).remove(key);
    if (!removed) throw Exception('Chưa xóa được bản phục hồi trên máy.');
  }
}
