import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'studio_meet_cockpit_tab.dart';
import 'studio_notes_settings_tab.dart';
import 'package:teaching_companion/core/ui/google_brand_icon.dart';

class StudioInspectorPanel extends StatefulWidget {
  const StudioInspectorPanel({
    super.key,
    required this.studio,
    required this.notesController,
    required this.questionController,
    required this.endpointController,
    required this.onPreview,
  });

  final StudioState studio;
  final TextEditingController notesController;
  final TextEditingController questionController;
  final TextEditingController endpointController;
  final VoidCallback onPreview;

  @override
  State<StudioInspectorPanel> createState() => _StudioInspectorPanelState();
}

class _StudioInspectorPanelState extends State<StudioInspectorPanel> {
  int _selectedTab = 0;
  final MeetAutomationService _meetService = MeetAutomationService();
  final GoogleMeetAuthService _authService = GoogleMeetAuthService();

  Widget _buildTabBar() {
    return ListenableBuilder(
      listenable: _meetService,
      builder: (context, _) {
        final isLive = _meetService.isHostJoined;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(
                    index: 0,
                    label: 'Trực tiếp',
                    icon: const GoogleBrandIcon(size: 14),
                    live: isLive,
                  ),
                ),
                Expanded(
                  child: _buildTab(
                    index: 1,
                    label: 'Thiết bị & Cài đặt',
                    icon: const Icon(Icons.settings_outlined, size: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab({
    required int index,
    required String label,
    required Widget icon,
    bool live = false,
  }) {
    final selected = _selectedTab == index;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 170),
          curve: AppMotion.stateCurve,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.control),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (live)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
              IconTheme(
                data: IconThemeData(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                child: icon,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? AppColors.slate800
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const line = AppColors.line;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: line)),
      ),
      child: Column(
        children: [
          // Header Tab Bar
          _buildTabBar(),
          const Divider(height: 1, color: line),

          // Tab Content
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, milliseconds: 190),
              switchInCurve: AppMotion.enterCurve,
              switchOutCurve: AppMotion.exitCurve,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0.025, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: _selectedTab == 0
                  ? ListenableBuilder(
                      key: const ValueKey('inspector-meet-tab'),
                      listenable: Listenable.merge([
                        _meetService,
                        _authService,
                      ]),
                      builder: (context, _) => StudioMeetCockpitTab(
                        meetService: _meetService,
                        authService: _authService,
                      ),
                    )
                  : StudioNotesSettingsTab(
                      key: const ValueKey('inspector-notes-tab'),
                      studio: widget.studio,
                      notesController: widget.notesController,
                      questionController: widget.questionController,
                      endpointController: widget.endpointController,
                      onPreview: widget.onPreview,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}


