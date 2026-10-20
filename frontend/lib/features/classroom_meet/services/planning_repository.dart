import 'dart:convert';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/core/utils/frontend_logger.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';

class PlanningRepository {
  PlanningRepository({LocalService? localService})
      : _service = localService ?? LocalService();

  final LocalService _service;

  Future<List<PlanningMeta>> getPlannings() async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        final res = await _service.client
            .get(Uri.parse('${_service.base}/api/plannings'), headers: headers)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is List) {
            return decoded
                .map((e) => PlanningMeta.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
        if (res.statusCode == 401 && attempt == 0) {
          FrontendLogger.write(
            '[PlanningRepository] getPlannings received 401. Refreshing token and retrying...',
          );
          continue;
        }
        FrontendLogger.write(
          '[PlanningRepository] getPlannings failed | status=${res.statusCode}',
        );
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] getPlannings attempt ${attempt + 1} error: $e',
        );
      }
    }
    return [];
  }

  Future<Map<String, dynamic>?> getPlanningContent(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        final res = await _service.client
            .get(Uri.parse('${_service.base}/api/plannings/$id'), headers: headers)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
        if (res.statusCode == 401 && attempt == 0) {
          FrontendLogger.write(
            '[PlanningRepository] getPlanningContent received 401. Refreshing token...',
          );
          continue;
        }
        FrontendLogger.write(
          '[PlanningRepository] getPlanningContent failed | status=${res.statusCode}',
        );
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] getPlanningContent attempt ${attempt + 1} error: $e',
        );
      }
    }
    return null;
  }

  Future<PlanningMeta?> createPlanning({
    required String title,
    required String subject,
    Map<String, dynamic>? content,
  }) async {
    final payload = <String, dynamic>{'title': title, 'subject': subject};
    if (content != null) payload['content'] = content;
    final body = jsonEncode(payload);

    FrontendLogger.write('[PlanningRepository] createPlanning started');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        FrontendLogger.write(
          '[PlanningRepository] createPlanning request sent | attempt=${attempt + 1}',
        );
        final res = await _service.client
            .post(
              Uri.parse('${_service.base}/api/plannings'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        FrontendLogger.write(
          '[PlanningRepository] createPlanning [attempt ${attempt + 1}]: HTTP ${res.statusCode}',
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          FrontendLogger.write('[PlanningRepository] createPlanning succeeded');
          return PlanningMeta.fromJson(decoded);
        }

        if (res.statusCode == 401 && attempt == 0) {
          FrontendLogger.write(
            '[PlanningRepository] Token rejected (401). Retrying with fresh token...',
          );
          continue;
        }

        FrontendLogger.write(
          '[PlanningRepository] createPlanning failed | status=${res.statusCode}',
        );
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] createPlanning exception | attempt=${attempt + 1} cause=${e.runtimeType}',
        );
      }
    }
    return null;
  }

  Future<PlanningMeta?> updatePlanning({
    required String id,
    String? title,
    String? subject,
    Map<String, dynamic>? content,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (subject != null) payload['subject'] = subject;
    if (content != null) payload['content'] = content;
    final body = jsonEncode(payload);

    FrontendLogger.write('[PlanningRepository] updatePlanning started');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        FrontendLogger.write(
          '[PlanningRepository] updatePlanning request sent | attempt=${attempt + 1}',
        );
        final res = await _service.client
            .put(
              Uri.parse('${_service.base}/api/plannings/$id'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10));

        FrontendLogger.write(
          '[PlanningRepository] updatePlanning [attempt ${attempt + 1}]: HTTP ${res.statusCode}',
        );

        if (res.statusCode == 200) {
          final decoded =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          FrontendLogger.write('[PlanningRepository] updatePlanning succeeded');
          return PlanningMeta.fromJson(decoded);
        }

        if (res.statusCode == 401 && attempt == 0) {
          FrontendLogger.write(
            '[PlanningRepository] Token rejected (401). Retrying with fresh token...',
          );
          continue;
        }

        FrontendLogger.write(
          '[PlanningRepository] updatePlanning failed | status=${res.statusCode}',
        );
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] updatePlanning exception | attempt=${attempt + 1} cause=${e.runtimeType}',
        );
      }
    }
    return null;
  }

  Future<bool> deletePlanning(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        final res = await _service.client
            .delete(Uri.parse('${_service.base}/api/plannings/$id'), headers: headers)
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded['success'] == true;
        }
        if (res.statusCode == 401 && attempt == 0) {
          continue;
        }
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] deletePlanning failed | cause=${e.runtimeType}',
        );
      }
    }
    return false;
  }

  Future<bool> clonePlanningToClassroom(String id) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final headers = await _service.getAuthHeaders(forceRefresh: attempt > 0);
        final res = await _service.client
            .post(
              Uri.parse('${_service.base}/api/plannings/$id/clone-to-classroom'),
              headers: headers,
              body: jsonEncode({}),
            )
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          return decoded['success'] == true;
        }
        if (res.statusCode == 401 && attempt == 0) {
          continue;
        }
        break;
      } catch (e) {
        FrontendLogger.write(
          '[PlanningRepository] clonePlanningToClassroom failed | cause=${e.runtimeType}',
        );
      }
    }
    return false;
  }
}

