import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';
import '../../services/google_meet_auth_service.dart';
import '../../services/meet_automation_service.dart';
import 'studio_meet_cockpit_tab.dart';
import 'studio_notes_settings_tab.dart';

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
  int _selectedTab = 0; // 0: Live Meet Cockpit, 1: Thiết bị & Ghi chú
  final MeetAutomationService _meetService = MeetAutomationService();
  final GoogleMeetAuthService _authService = GoogleMeetAuthService();

  Widget _buildTabBar() {
    return ListenableBuilder(
      listenable: _meetService,
      builder: (context, _) {
        final handCount = _meetService.raisedHands.length;
        final hasLiveRoom = _meetService.hasRoom;

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
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 0),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 0
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        boxShadow: _selectedTab == 0
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
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasLiveRoom
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Flexible(
                            child: Text(
                              'Trực tiếp',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate800,
                              ),
                            ),
                          ),
                          if (handCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.control,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.front_hand_outlined, size: 9, color: Colors.white),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$handCount',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedTab = 1),
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        boxShadow: _selectedTab == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: const Center(
                        child: Text(
                          'Cài đặt & Ghi chú',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            child: _selectedTab == 0
                ? ListenableBuilder(
                    listenable: Listenable.merge([_meetService, _authService]),
                    builder: (context, _) => StudioMeetCockpitTab(
                      meetService: _meetService,
                      authService: _authService,
                    ),
                  )
                : StudioNotesSettingsTab(
                    studio: widget.studio,
                    notesController: widget.notesController,
                    questionController: widget.questionController,
                    endpointController: widget.endpointController,
                    onPreview: widget.onPreview,
                  ),
          ),
        ],
      ),
    );
  }
}
