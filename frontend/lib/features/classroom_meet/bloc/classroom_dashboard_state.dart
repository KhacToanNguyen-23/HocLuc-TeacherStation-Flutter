import 'package:flutter/foundation.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';

/// State representation for the classroom dashboard (rooms, history, and plannings).
@immutable
class ClassroomDashboardState {
  const ClassroomDashboardState({
    this.activeRoom,
    this.historyList = const [],
    this.plannings = const [],
    this.loadingPlannings = false,
    this.loadingRooms = false,
    this.selectedTabIndex = 0,
    this.selectedRoomFilter = 'Tất cả',
    this.selectedSubjectFilter = 'Tất cả',
    this.errorMessage,
  });

  final Map<String, dynamic>? activeRoom;
  final List<dynamic> historyList;
  final List<PlanningMeta> plannings;
  final bool loadingPlannings;
  final bool loadingRooms;
  final int selectedTabIndex;
  final String selectedRoomFilter;
  final String selectedSubjectFilter;
  final String? errorMessage;

  bool get hasOngoingRoom =>
      activeRoom != null && activeRoom!['status'] == 'ONGOING';

  List<PlanningMeta> get filteredPlannings {
    if (selectedSubjectFilter == 'Tất cả') return plannings;
    return plannings.where((p) => p.subject == selectedSubjectFilter).toList();
  }

  ClassroomDashboardState copyWith({
    Map<String, dynamic>? Function()? activeRoom,
    List<dynamic>? historyList,
    List<PlanningMeta>? plannings,
    bool? loadingPlannings,
    bool? loadingRooms,
    int? selectedTabIndex,
    String? selectedRoomFilter,
    String? selectedSubjectFilter,
    String? Function()? errorMessage,
  }) {
    return ClassroomDashboardState(
      activeRoom: activeRoom != null ? activeRoom() : this.activeRoom,
      historyList: historyList ?? this.historyList,
      plannings: plannings ?? this.plannings,
      loadingPlannings: loadingPlannings ?? this.loadingPlannings,
      loadingRooms: loadingRooms ?? this.loadingRooms,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedRoomFilter: selectedRoomFilter ?? this.selectedRoomFilter,
      selectedSubjectFilter:
          selectedSubjectFilter ?? this.selectedSubjectFilter,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassroomDashboardState &&
          runtimeType == other.runtimeType &&
          mapEquals(activeRoom, other.activeRoom) &&
          listEquals(historyList, other.historyList) &&
          listEquals(plannings, other.plannings) &&
          loadingPlannings == other.loadingPlannings &&
          loadingRooms == other.loadingRooms &&
          selectedTabIndex == other.selectedTabIndex &&
          selectedRoomFilter == other.selectedRoomFilter &&
          selectedSubjectFilter == other.selectedSubjectFilter &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    activeRoom,
    historyList,
    plannings,
    loadingPlannings,
    loadingRooms,
    selectedTabIndex,
    selectedRoomFilter,
    selectedSubjectFilter,
    errorMessage,
  );

  @override
  String toString() {
    final activeStatus = activeRoom != null
        ? 'Active(${activeRoom!['status'] ?? 'UNKNOWN'})'
        : 'None';
    return 'ClassroomDashboardState('
        'tab: $selectedTabIndex, '
        'activeRoom: $activeStatus, '
        'roomsLoading: $loadingRooms, '
        'historyCount: ${historyList.length}, '
        'planningsCount: ${plannings.length}, '
        'planningsLoading: $loadingPlannings, '
        'roomFilter: "$selectedRoomFilter", '
        'subjectFilter: "$selectedSubjectFilter"'
        '${errorMessage != null ? ', error: "$errorMessage"' : ''})';
  }
}
