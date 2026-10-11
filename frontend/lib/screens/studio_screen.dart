import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import '../widgets/stage_container.dart';
import '../widgets/studio/studio_drawing_toolbar.dart';
import '../widgets/studio/studio_inspector_panel.dart';
import '../widgets/studio/studio_lessons_drawer.dart';
import '../widgets/studio/studio_preview_dialog.dart';
import '../widgets/studio/studio_question_view.dart';
import '../widgets/studio/studio_rename_dialog.dart';
import '../widgets/studio/studio_top_bar.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, this.initialState});
  final StudioState? initialState;
  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final StudioState studio;
  final notes = TextEditingController();
  final question = TextEditingController();
  final endpoint = TextEditingController();
  bool initializedControllers = false;
  bool showLessons = false;
  bool showInspector = false;

  @override
  void initState() {
    super.initState();
    studio = widget.initialState ?? StudioState();
    if (widget.initialState == null) studio.initialize();
    studio.addListener(syncControllers);
  }

  void syncControllers() {
    if (!studio.loading && !initializedControllers) {
      notes.text = studio.notes;
      question.text = studio.question;
      endpoint.text = studio.endpoint;
      initializedControllers = true;
    }
  }

  @override
  void dispose() {
    studio.removeListener(syncControllers);
    studio.dispose();
    notes.dispose();
    question.dispose();
    endpoint.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> save() async {
    final success = await studio.save();
    if (mounted) {
      message(
        success
            ? 'Đã lưu bài giảng và cấu hình trên máy.'
            : 'Không lưu được. Kiểm tra dịch vụ Java rồi thử lại.',
      );
    }
  }

  void preview() => StudioPreviewDialog.show(context, studio);

  Future<void> rename() async {
    final result = await StudioRenameDialog.show(context, studio.title);
    if (result != null && result.isNotEmpty) {
      studio.change(() => studio.title = result);
    }
  }

  void openInspector() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: AnimatedBuilder(
        animation: studio,
        builder: (_, _) => StudioInspectorPanel(
          studio: studio,
          notesController: notes,
          questionController: question,
          endpointController: endpoint,
          onPreview: preview,
        ),
      ),
    ),
  );

  void openLessons() => showModalBottomSheet<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: studio,
      builder: (_, _) => SizedBox(
        height: 410,
        child: StudioLessonsDrawer(
          studio: studio,
          onClose: () => Navigator.pop(context),
          onPluginMessage: message,
        ),
      ),
    ),
  );

  Widget fittedStage({bool interactive = true}) {
    if (studio.view == 'question') {
      return StudioQuestionView(studio: studio);
    }
    return StageContainer(studio: studio, interactive: interactive);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: studio,
    builder: (context, _) {
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final hasInspector = showInspector && box.maxWidth >= 1250;
            final hasLessons = showLessons && box.maxWidth >= 1000;

            return Column(
              children: [
                StudioTopBar(
                  studio: studio,
                  width: box.maxWidth,
                  hasLessons: hasLessons,
                  hasInspector: hasInspector,
                  onToggleLessons: () {
                    if (box.maxWidth < 1000) {
                      openLessons();
                    } else {
                      setState(() => showLessons = !showLessons);
                    }
                  },
                  onToggleInspector: () {
                    if (box.maxWidth < 1250) {
                      openInspector();
                    } else {
                      setState(() => showInspector = !showInspector);
                    }
                  },
                  onRename: rename,
                  onPreview: preview,
                  onSave: save,
                  onRetryConnect: () {
                    initializedControllers = false;
                    studio.initialize();
                  },
                ),
                Expanded(
                  child: Row(
                    children: [
                      if (hasLessons)
                        SizedBox(
                          width: 200,
                          child: StudioLessonsDrawer(
                            studio: studio,
                            onClose: () => setState(() => showLessons = false),
                            onPluginMessage: message,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  6,
                                  10,
                                  4,
                                ),
                                child: fittedStage(),
                              ),
                            ),
                            if (studio.view == 'board')
                              StudioDrawingToolbar(studio: studio),
                          ],
                        ),
                      ),
                      if (hasInspector)
                        SizedBox(
                          width: 304,
                          child: StudioInspectorPanel(
                            studio: studio,
                            notesController: notes,
                            questionController: question,
                            endpointController: endpoint,
                            onPreview: preview,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
