import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/services/planning_repository.dart';
import 'classroom_dashboard_state.dart';

export 'classroom_dashboard_state.dart';

/// Cubit managing ongoing rooms, session history, and lesson plannings for the dashboard.
class ClassroomDashboardCubit extends Cubit<ClassroomDashboardState> {
  ClassroomDashboardCubit({
    LocalService? localService,
    PlanningRepository? planningRepository,
  }) : this._internal(localService ?? LocalService(), planningRepository);

  ClassroomDashboardCubit._internal(
    LocalService localService,
    PlanningRepository? planningRepository,
  ) : _localService = localService,
      _planningRepository =
          planningRepository ?? PlanningRepository(localService: localService),
      super(const ClassroomDashboardState());

  final LocalService _localService;
  final PlanningRepository _planningRepository;

  int _roomsRequestId = 0;
  int _planningsRequestId = 0;

  /// Loads both active room/history and lesson plannings simultaneously.
  Future<void> loadAll() async {
    await Future.wait([loadRoomsAndHistory(), loadPlannings()]);
  }

  /// Fetches ongoing room status and past session history.
  Future<void> loadRoomsAndHistory() async {
    if (isClosed) return;
    final reqId = ++_roomsRequestId;
    emit(state.copyWith(loadingRooms: true));
    try {
      final active = await _localService.getActiveClassroom();
      final history = await _localService.getClassroomHistory();
      if (isClosed || reqId != _roomsRequestId) return;
      final hasOngoing = active.isNotEmpty && active['status'] == 'ONGOING';
      emit(
        state.copyWith(
          activeRoom: () => hasOngoing ? active : null,
          historyList: history,
          loadingRooms: false,
          errorMessage: () => null,
        ),
      );
    } catch (e) {
      if (isClosed || reqId != _roomsRequestId) return;
      emit(
        state.copyWith(
          loadingRooms: false,
          errorMessage: () => 'Không thể tải phòng học: $e',
        ),
      );
    }
  }

  /// Fetches lesson planning documents from the repository.
  Future<void> loadPlannings() async {
    if (isClosed) return;
    final reqId = ++_planningsRequestId;
    emit(state.copyWith(loadingPlannings: true));
    try {
      final list = await _planningRepository.getPlannings();
      if (isClosed || reqId != _planningsRequestId) return;
      emit(
        state.copyWith(
          plannings: list,
          loadingPlannings: false,
          errorMessage: () => null,
        ),
      );
    } catch (e) {
      if (isClosed || reqId != _planningsRequestId) return;
      emit(
        state.copyWith(
          loadingPlannings: false,
          errorMessage: () => 'Không thể tải kế hoạch bài giảng: $e',
        ),
      );
    }
  }

  /// Clears active error message once consumed by the UI to prevent duplicate alerts.
  void clearError() {
    if (isClosed || state.errorMessage == null) return;
    emit(state.copyWith(errorMessage: () => null));
  }

  /// Switches active tab (0: Rooms, 1: Plannings, 2: History).
  Future<void> setTabIndex(int index) async {
    if (state.selectedTabIndex == index || isClosed) return;
    emit(state.copyWith(selectedTabIndex: index));
    if (index == 1) {
      await loadPlannings();
    } else {
      await loadRoomsAndHistory();
    }
  }

  /// Sets room filter (e.g. 'Tất cả', 'Đang diễn ra', 'Đã lên lịch').
  void setRoomFilter(String filter) {
    if (isClosed) return;
    emit(state.copyWith(selectedRoomFilter: filter));
  }

  /// Sets subject filter (e.g. 'Tất cả', 'Tiếng Anh', 'Toán').
  void setSubjectFilter(String filter) {
    if (isClosed) return;
    emit(state.copyWith(selectedSubjectFilter: filter));
  }

  /// Creates a new lesson planning document.
  Future<PlanningMeta?> createPlanning({
    required String title,
    required String subject,
  }) async {
    try {
      final newPlan = await _planningRepository.createPlanning(
        title: title,
        subject: subject,
      );
      await loadPlannings();
      return newPlan;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          errorMessage: () => 'Không thể tạo kế hoạch bài giảng: $e',
        ),
      );
      return null;
    }
  }

  /// Deletes an existing lesson planning document by ID.
  Future<void> deletePlanning(String planId) async {
    try {
      await _planningRepository.deletePlanning(planId);
      await loadPlannings();
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          errorMessage: () => 'Không thể xóa kế hoạch bài giảng: $e',
        ),
      );
    }
  }
}
