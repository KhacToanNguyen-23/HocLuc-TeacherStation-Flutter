import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/bloc/classroom_dashboard_cubit.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/features/classroom_meet/services/planning_repository.dart';

class _FakeLocalService extends LocalService {
  Map<String, dynamic> fakeActive = {};
  List<dynamic> fakeHistory = [];
  bool shouldFail = false;

  @override
  Future<Map<String, dynamic>> getActiveClassroom({bool strict = false}) async {
    if (shouldFail) throw StateError('Local service offline');
    return fakeActive;
  }

  @override
  Future<List<dynamic>> getClassroomHistory({String? teacherId}) async {
    if (shouldFail) throw StateError('Local service offline');
    return fakeHistory;
  }
}

class _FakePlanningRepository extends PlanningRepository {
  _FakePlanningRepository() : super(localService: _FakeLocalService());

  bool shouldFailCreate = false;
  bool shouldFailLoad = false;
  Completer<List<PlanningMeta>>? delayedLoadCompleter;

  final List<PlanningMeta> plans = [
    PlanningMeta(
      id: 'plan-1',
      title: 'Unit 1: Greetings',
      subject: 'Tiếng Anh',
      createdAt: 1700000000,
      updatedAt: 1700000000,
    ),
    PlanningMeta(
      id: 'plan-2',
      title: 'Đại số: Hàm số bậc nhất',
      subject: 'Toán',
      createdAt: 1700000000,
      updatedAt: 1700000000,
    ),
  ];

  @override
  Future<List<PlanningMeta>> getPlannings() async {
    if (shouldFailLoad) throw StateError('Repository network error');
    if (delayedLoadCompleter != null) return delayedLoadCompleter!.future;
    return List.of(plans);
  }

  @override
  Future<PlanningMeta?> createPlanning({
    required String title,
    required String subject,
    Map<String, dynamic>? content,
  }) async {
    if (shouldFailCreate) throw StateError('Backend create 500');
    final newPlan = PlanningMeta(
      id: 'plan-${plans.length + 1}',
      title: title,
      subject: subject,
      createdAt: 1700000000,
      updatedAt: 1700000000,
    );
    plans.add(newPlan);
    return newPlan;
  }

  @override
  Future<bool> deletePlanning(String id) async {
    plans.removeWhere((p) => p.id == id);
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ClassroomDashboardCubit Unit Tests', () {
    test('initial state has default filters and empty data', () {
      final cubit = ClassroomDashboardCubit(
        localService: _FakeLocalService(),
        planningRepository: _FakePlanningRepository(),
      );
      expect(cubit.state.selectedTabIndex, 0);
      expect(cubit.state.selectedRoomFilter, 'Tất cả');
      expect(cubit.state.selectedSubjectFilter, 'Tất cả');
      expect(cubit.state.plannings, isEmpty);
      expect(cubit.state.historyList, isEmpty);
      expect(cubit.state.activeRoom, isNull);
      expect(cubit.state.toString(), contains('tab: 0'));
      expect(cubit.state.toString(), contains('activeRoom: None'));
      cubit.close();
    });

    test(
      'constructor shares localService with PlanningRepository by default',
      () {
        final fakeLocal = _FakeLocalService();
        final cubit = ClassroomDashboardCubit(localService: fakeLocal);
        expect(cubit.state, isNotNull);
        cubit.close();
      },
    );

    test(
      'loadRoomsAndHistory populates active ongoing room and past history',
      () async {
        final fakeLocal = _FakeLocalService()
          ..fakeActive = {
            'title': 'Phòng 12A1',
            'status': 'ONGOING',
            'meetingUrl': 'https://meet.google.com/abc',
          }
          ..fakeHistory = [
            {'title': 'Phòng 10B2', 'status': 'ENDED'},
          ];

        final cubit = ClassroomDashboardCubit(
          localService: fakeLocal,
          planningRepository: _FakePlanningRepository(),
        );
        await cubit.loadRoomsAndHistory();

        expect(cubit.state.hasOngoingRoom, isTrue);
        expect(cubit.state.activeRoom?['title'], 'Phòng 12A1');
        expect(cubit.state.historyList.length, 1);
        cubit.close();
      },
    );

    test(
      'loadPlannings populates planning items and filteredPlannings works',
      () async {
        final fakeRepo = _FakePlanningRepository();
        final cubit = ClassroomDashboardCubit(
          localService: _FakeLocalService(),
          planningRepository: fakeRepo,
        );

        await cubit.loadPlannings();
        expect(cubit.state.plannings.length, 2);
        expect(cubit.state.filteredPlannings.length, 2);

        cubit.setSubjectFilter('Tiếng Anh');
        expect(cubit.state.filteredPlannings.length, 1);
        expect(cubit.state.filteredPlannings.first.subject, 'Tiếng Anh');

        cubit.setSubjectFilter('Tất cả');
        expect(cubit.state.filteredPlannings.length, 2);
        cubit.close();
      },
    );

    test('setTabIndex switches tab and triggers reload', () async {
      final fakeLocal = _FakeLocalService();
      final fakeRepo = _FakePlanningRepository();
      final cubit = ClassroomDashboardCubit(
        localService: fakeLocal,
        planningRepository: fakeRepo,
      );

      await cubit.setTabIndex(1);
      expect(cubit.state.selectedTabIndex, 1);

      await cubit.setTabIndex(2);
      expect(cubit.state.selectedTabIndex, 2);
      cubit.close();
    });

    test('createPlanning adds new plan and updates state', () async {
      final fakeLocal = _FakeLocalService();
      final fakeRepo = _FakePlanningRepository();
      final cubit = ClassroomDashboardCubit(
        localService: fakeLocal,
        planningRepository: fakeRepo,
      );

      final created = await cubit.createPlanning(
        title: 'Sinh học tế bào',
        subject: 'Sinh học',
      );

      expect(created, isNotNull);
      expect(created?.title, 'Sinh học tế bào');
      expect(cubit.state.plannings.length, 3);
      cubit.close();
    });

    test('deletePlanning removes plan and updates state', () async {
      final fakeLocal = _FakeLocalService();
      final fakeRepo = _FakePlanningRepository();
      final cubit = ClassroomDashboardCubit(
        localService: fakeLocal,
        planningRepository: fakeRepo,
      );
      await cubit.loadPlannings();

      await cubit.deletePlanning('plan-1');
      expect(cubit.state.plannings.length, 1);
      expect(cubit.state.plannings.first.id, 'plan-2');
      cubit.close();
    });

    test(
      'createPlanning failure sets errorMessage and returns null without throwing',
      () async {
        final fakeLocal = _FakeLocalService();
        final fakeRepo = _FakePlanningRepository()..shouldFailCreate = true;
        final cubit = ClassroomDashboardCubit(
          localService: fakeLocal,
          planningRepository: fakeRepo,
        );

        final result = await cubit.createPlanning(
          title: 'Thất bại tạo',
          subject: 'Toán',
        );

        expect(result, isNull);
        expect(cubit.state.errorMessage, contains('Không thể tạo'));
        cubit.clearError();
        expect(cubit.state.errorMessage, isNull);
        cubit.close();
      },
    );

    test(
      'loadRoomsAndHistory failure captures errorMessage while keeping existing data',
      () async {
        final fakeLocal = _FakeLocalService()
          ..fakeHistory = [
            {'title': 'Phòng cũ'},
          ];
        final fakeRepo = _FakePlanningRepository();
        final cubit = ClassroomDashboardCubit(
          localService: fakeLocal,
          planningRepository: fakeRepo,
        );

        await cubit.loadRoomsAndHistory();
        expect(cubit.state.historyList.length, 1);

        // Now induce failure
        fakeLocal.shouldFail = true;
        await cubit.loadRoomsAndHistory();

        // Prior history must be preserved, error recorded
        expect(cubit.state.historyList.length, 1);
        expect(cubit.state.errorMessage, contains('Không thể tải phòng học'));
        cubit.close();
      },
    );

    test('setRoomFilter updates selectedRoomFilter', () {
      final cubit = ClassroomDashboardCubit(
        localService: _FakeLocalService(),
        planningRepository: _FakePlanningRepository(),
      );

      cubit.setRoomFilter('Đang diễn ra');
      expect(cubit.state.selectedRoomFilter, 'Đang diễn ra');

      cubit.setRoomFilter('Đã lên lịch');
      expect(cubit.state.selectedRoomFilter, 'Đã lên lịch');
      cubit.close();
    });

    test('stale asynchronous responses cannot overwrite newer state', () async {
      final fakeRepo = _FakePlanningRepository();
      final delayedCompleter = Completer<List<PlanningMeta>>();
      fakeRepo.delayedLoadCompleter = delayedCompleter;

      final cubit = ClassroomDashboardCubit(
        localService: _FakeLocalService(),
        planningRepository: fakeRepo,
      );

      // Request 1: delayed
      final future1 = cubit.loadPlannings();

      // Request 2: finishes immediately with updated repository
      fakeRepo.delayedLoadCompleter = null;
      fakeRepo.plans.clear();
      fakeRepo.plans.add(
        PlanningMeta(
          id: 'plan-fresh',
          title: 'Bài giảng mới nhất',
          subject: 'Toán',
          createdAt: 1700000000,
          updatedAt: 1700000000,
        ),
      );
      await cubit.loadPlannings();
      expect(cubit.state.plannings.length, 1);
      expect(cubit.state.plannings.first.id, 'plan-fresh');

      // Now complete Request 1 with stale data
      delayedCompleter.complete([
        PlanningMeta(
          id: 'plan-stale',
          title: 'Bài giảng cũ',
          subject: 'Lý',
          createdAt: 1700000000,
          updatedAt: 1700000000,
        ),
      ]);
      await future1;

      // Verification: Request 1 must NOT overwrite the state of Request 2
      expect(cubit.state.plannings.length, 1);
      expect(cubit.state.plannings.first.id, 'plan-fresh');
      cubit.close();
    });
  });

  group('ClassroomDashboardScreen Widget Integration with Cubit', () {
    testWidgets('renders tabs, plannings, and filters smoothly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeLocal = _FakeLocalService();
      final fakeRepo = _FakePlanningRepository();
      final cubit = ClassroomDashboardCubit(
        localService: fakeLocal,
        planningRepository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(home: ClassroomDashboardScreen(cubit: cubit)),
      );
      await tester.pumpAndSettle();

      // Tab 0: Rooms
      expect(find.text('Phòng học'), findsWidgets);
      expect(find.text('Chưa có phòng học'), findsOneWidget);

      // Switch to Tab 1: Plannings
      cubit.setTabIndex(1);
      await tester.pumpAndSettle();

      expect(find.text('Kế hoạch bài giảng'), findsWidgets);
      expect(find.text('Unit 1: Greetings'), findsOneWidget);
      expect(find.text('Đại số: Hàm số bậc nhất'), findsOneWidget);

      // Switch to Tab 2: History
      cubit.setTabIndex(2);
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử'), findsWidgets);

      cubit.close();
    });
  });
}
