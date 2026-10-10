import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/studio_state.dart';
import 'widgets/stage_container.dart';
import 'widgets/interactive_chalkboard.dart';

const pine = Color(0xff173e35);
const muted = Color(0xff728078);
const paper = Color(0xfff5f5ed);
const lime = Color(0xffd4e8a6);
const line = Color(0xffe1e5db);

void main() => runApp(const CompanionApp());

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mộc · Teaching Studio',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: pine,
        primary: pine,
        surface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: pine),
        bodySmall: TextStyle(fontSize: 11, color: muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xfff6f7f2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pine,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    ),
    home: const StudioScreen(),
  );
}

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

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  void preview() {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: const Color(0xff101e19),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.crop_landscape, color: lime),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Khung trình bày · chưa phát qua camera ảo',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng xem trước',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: studio,
                  builder: (_, _) => fittedStage(interactive: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> rename() async {
    final input = TextEditingController(text: studio.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tên bài giảng'),
        content: TextField(controller: input, autofocus: true, maxLength: 100),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Đổi tên'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null && result.isNotEmpty) {
      studio.change(() => studio.title = result);
    }
  }

  void openInspector() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: AnimatedBuilder(animation: studio, builder: (_, _) => inspector()),
    ),
  );
  void openLessons() => showModalBottomSheet<void>(
    context: context,
    builder: (_) => AnimatedBuilder(
      animation: studio,
      builder: (_, _) => SizedBox(height: 410, child: lessons()),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: studio,
    builder: (context, _) {
      syncControllers();
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, box) {
            final hasInspector = showInspector && box.maxWidth >= 1250,
                hasLessons = showLessons && box.maxWidth >= 1000;
            return Column(
              children: [
                studioTopBar(box.maxWidth, hasLessons, hasInspector),
                Expanded(
                  child: Row(
                    children: [
                      if (hasLessons) SizedBox(width: 200, child: lessons()),
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
                            if (studio.view == 'board') drawingToolbar(),
                          ],
                        ),
                      ),
                      if (hasInspector)
                        SizedBox(width: 304, child: inspector()),
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

  Widget studioTopBar(
    double width,
    bool hasLessons,
    bool hasInspector,
  ) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: pine,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'm',
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: lime,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: hasLessons ? 'Đóng mục bài giảng' : 'Mở mục bài giảng',
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          onPressed: () {
            if (width < 1000) {
              openLessons();
            } else {
              setState(() => showLessons = !showLessons);
            }
          },
          icon: Icon(
            hasLessons ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            color: pine,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: InkWell(
            onTap: rename,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      studio.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined, size: 13, color: muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (!studio.online)
          Tooltip(
            message: studio.error ?? 'Chưa kết nối Java. Bấm để thử lại.',
            child: InkWell(
              onTap: studio.loading
                  ? null
                  : () {
                      initializedControllers = false;
                      studio.initialize();
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffffeed9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffffcc80)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off, size: 11, color: Color(0xffe65100)),
                    SizedBox(width: 4),
                    Text(
                      'Thử lại',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffe65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffedf6ec),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffc8e6c9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 6, color: Color(0xff43a047)),
                const SizedBox(width: 4),
                Text(
                  studio.dirty ? 'Chưa lưu' : 'Java OK',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff2e7d32),
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Bảng giảng',
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () => studio.setView('board'),
          style: IconButton.styleFrom(
            backgroundColor: studio.view == 'board'
                ? const Color(0xffedf2e5)
                : Colors.transparent,
          ),
          icon: Icon(
            Icons.dashboard_outlined,
            color: studio.view == 'board' ? pine : muted,
          ),
        ),
        const SizedBox(width: 3),
        IconButton(
          tooltip: 'Câu hỏi',
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () =>
              studio.setView(studio.view == 'question' ? 'board' : 'question'),
          style: IconButton.styleFrom(
            backgroundColor: studio.view == 'question'
                ? const Color(0xffedf2e5)
                : Colors.transparent,
          ),
          icon: Icon(
            Icons.quiz_outlined,
            color: studio.view == 'question' ? pine : muted,
          ),
        ),
        const SizedBox(width: 3),
        IconButton(
          tooltip: 'Xem khung trình bày',
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: preview,
          icon: const Icon(Icons.slideshow_outlined, color: pine),
        ),
        const SizedBox(width: 3),
        IconButton(
          tooltip: 'Thiết bị và API AI',
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: () {
            if (width < 1250) {
              openInspector();
            } else {
              setState(() => showInspector = !showInspector);
            }
          },
          icon: Icon(
            showInspector ? Icons.tune : Icons.tune_outlined,
            color: showInspector ? pine : muted,
          ),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: studio.saving || studio.loading ? null : save,
          icon: const Icon(Icons.save_outlined, size: 14),
          label: Text(
            width > 900 ? (studio.saving ? 'Đang lưu…' : 'Lưu bài') : '',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: pine,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: width > 900 ? 12 : 8,
              vertical: 7,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget lessons() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      children: [
        Row(
          children: [
            const Icon(Icons.layers_outlined, size: 15, color: pine),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'CÁC TRANG BẢNG',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: pine,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'P.${studio.page + 1}/3',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: muted,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => setState(() => showLessons = false),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close, size: 14, color: muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final (index, label) in [
          (0, 'Khám phá hàm số'),
          (1, 'Giải thích bảng'),
          (2, 'Luyện tập'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () => studio.change(() {
                studio.page = index;
                studio.view = 'board';
              }),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: studio.page == index && studio.view == 'board'
                      ? const Color(0xfff0f4e8)
                      : Colors.white,
                  border: Border.all(
                    color: studio.page == index && studio.view == 'board'
                        ? const Color(0xffadc38c)
                        : line,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: studio.page == index && studio.view == 'board'
                            ? pine
                            : const Color(0xfff0f2eb),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                studio.page == index && studio.view == 'board'
                                ? lime
                                : muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              studio.page == index && studio.view == 'board'
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: pine,
                        ),
                      ),
                    ),
                    Icon(
                      index == 0 ? Icons.show_chart : Icons.draw_outlined,
                      size: 13,
                      color: studio.page == index && studio.view == 'board'
                          ? pine
                          : muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: line),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.extension_outlined, size: 13, color: muted),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'TIỆN ÍCH MÔN HỌC',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xffedf2e5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Plugins',
                style: TextStyle(
                  fontSize: 8,
                  color: pine,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            message(
              'Hệ thống Extension Microkernel: Sẵn sàng kết nối plugin bộ môn (Tiếng Anh, Toán, Khoa học…).',
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xfff8f9f5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xffdbe2d4),
                style: BorderStyle.solid,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline, size: 15, color: pine),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cài thêm tiện ích môn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: pine,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget fittedStage({bool interactive = true}) => LayoutBuilder(
    builder: (context, constraints) {
      if (studio.view == 'question') {
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * 16 / 9,
        );
        return Center(
          child: SizedBox(
            width: width,
            height: width * 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: const Color(0xff14221d),
                child: questionStage(),
              ),
            ),
          ),
        );
      }
      return StageContainer(studio: studio, interactive: interactive);
    },
  );

  Widget boardStage(bool interactive) =>
      InteractiveChalkboard(studio: studio, interactive: interactive);

  Widget questionStage() => LayoutBuilder(
    builder: (context, box) => Padding(
      padding: EdgeInsets.all(box.maxWidth * .06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CÙNG SUY NGHĨ / Q1',
            style: TextStyle(
              fontSize: box.maxWidth * .015,
              letterSpacing: 2,
              color: muted,
            ),
          ),
          SizedBox(height: box.maxHeight * .05),
          Expanded(
            child: Text(
              studio.question,
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: box.maxWidth * .031,
                height: 1.5,
              ),
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final (i, option) in [
                '(−1; −4)',
                '(1; −4)',
                '(1; 4)',
                '(−1; 4)',
              ].indexed)
                Container(
                  width: (box.maxWidth * .88 - 12) / 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: studio.reveal && i == 1
                        ? lime
                        : const Color(0xfff2f3e9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${String.fromCharCode(65 + i)}. $option',
                    style: TextStyle(
                      fontSize: box.maxWidth * .022,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: box.maxHeight * .04),
          Text(
            studio.reveal
                ? 'Đáp án mẫu: B · x = −b/2a = 1; y = −4.'
                : 'Trả lời trong chat Meet theo mẫu: Q1 A / Q1 B / Q1 C / Q1 D',
            style: TextStyle(fontSize: box.maxWidth * .014, color: muted),
          ),
        ],
      ),
    ),
  );

  Widget drawingToolbar() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 3,
          children: [
            for (final (name, icon, label) in [
              ('pen', Icons.edit_outlined, 'Bút vẽ'),
              ('highlight', Icons.brush_outlined, 'Bút đánh dấu'),
              ('erase', Icons.auto_fix_normal, 'Tẩy nét'),
              ('laser', Icons.adjust, 'Chấm Laser (Chỉ trỏ)'),
            ])
              IconButton(
                tooltip: label,
                onPressed: () =>
                    studio.change(() => studio.tool = name, persist: false),
                style: IconButton.styleFrom(
                  backgroundColor: studio.tool == name
                      ? const Color(0xffedf2e5)
                      : Colors.transparent,
                ),
                icon: Icon(icon, size: 19, color: pine),
              ),
            const SizedBox(width: 8),
            for (final (color, label) in [
              (const Color(0xfff0f3ed), 'Trắng phấn'),
              (const Color(0xffffe66d), 'Vàng phấn'),
              (const Color(0xff70e0d0), 'Xanh phấn'),
              (const Color(0xffff8c69), 'Cam phấn'),
              (const Color(0xffff85a2), 'Hồng phấn'),
            ])
              Tooltip(
                message: label,
                child: InkWell(
                  onTap: () =>
                      studio.change(() => studio.ink = color, persist: false),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: studio.ink == color
                            ? pine
                            : const Color(0xffd5dcd2),
                        width: studio.ink == color ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        if (studio.ink == color)
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Hoàn tác nét (Ctrl+Z)',
              onPressed: studio.canUndo ? studio.undo : null,
              icon: const Icon(Icons.undo, size: 19),
            ),
            IconButton(
              tooltip: 'Làm lại nét (Ctrl+Y)',
              onPressed: studio.canRedo ? studio.redo : null,
              icon: const Icon(Icons.redo, size: 19),
            ),
            IconButton(
              tooltip: 'Xóa nét trang này',
              onPressed: studio.strokes.isEmpty ? null : studio.clearPage,
              icon: const Icon(Icons.delete_outline, size: 19),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 20, color: line),
            const SizedBox(width: 6),
            Tooltip(
              message: 'Trang trước',
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: studio.page > 0 ? studio.prevPage : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${studio.page + 1}/${studio.pages.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: pine,
                ),
              ),
            ),
            Tooltip(
              message: 'Trang sau',
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: studio.nextPage,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ),
            Tooltip(
              message: 'Thêm trang mới',
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: studio.addPage,
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: pine,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 20, color: line),
            const SizedBox(width: 6),
            IconButton(
              tooltip: studio.showCameraPip
                  ? 'Ẩn Webcam PIP'
                  : 'Hiện Webcam PIP',
              onPressed: studio.toggleCameraPip,
              style: IconButton.styleFrom(
                backgroundColor: studio.showCameraPip
                    ? const Color(0xffedf2e5)
                    : Colors.transparent,
              ),
              icon: Icon(
                studio.showCameraPip
                    ? Icons.videocam
                    : Icons.videocam_off_outlined,
                size: 19,
                color: pine,
              ),
            ),
            IconButton(
              tooltip: studio.showQuestionsDrawer
                  ? 'Đóng khay tài liệu đã nhập'
                  : 'Mở khay tài liệu đã nhập',
              onPressed: studio.toggleQuestionsDrawer,
              style: IconButton.styleFrom(
                backgroundColor: studio.showQuestionsDrawer
                    ? const Color(0xffedf2e5)
                    : Colors.transparent,
              ),
              icon: const Icon(
                Icons.collections_bookmark_outlined,
                size: 19,
                color: pine,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget inspector() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(left: BorderSide(color: line)),
    ),
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Chuẩn bị buổi dạy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        const Text(
          'Điều khiển riêng của giáo viên',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        const SizedBox(height: 22),
        sectionLabel('ĐẦU RA CHO MEETING'),
        const SizedBox(height: 10),
        Container(
          height: 128,
          decoration: BoxDecoration(
            color: const Color(0xffeef1e7),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 27, color: muted),
              const SizedBox(height: 9),
              const Text('Camera chưa kết nối', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 5),
              TextButton(
                onPressed: preview,
                child: const Text(
                  'Xem khung trình bày →',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        statusLine(Icons.videocam_outlined, 'Camera ảo', 'Cần native bridge'),
        statusLine(Icons.mic_none_outlined, 'Micro ảo', 'Cần native bridge'),
        const SizedBox(height: 18),
        const Divider(color: line),
        const SizedBox(height: 14),
        sectionLabel('ÂM THANH & API AI'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: studio.microphone,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Microphone'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Chọn thiết bị', style: TextStyle(fontSize: 11)),
            ),
            ...studio.microphones.map(
              (m) => DropdownMenuItem(
                value: m['id'] as String,
                child: Text(
                  m['name'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
          onChanged: (value) =>
              studio.change(() => studio.microphone = value ?? ''),
        ),
        const SizedBox(height: 7),
        const Text(
          'Danh sách từ JavaSound; chưa thu âm.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: endpoint,
          decoration: const InputDecoration(
            labelText: 'API AI của bạn',
            hintText: 'https://ai.example.vn',
          ),
          style: const TextStyle(fontSize: 12),
          onChanged: (v) => studio.change(() => studio.endpoint = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: studio.language,
          decoration: const InputDecoration(labelText: 'Ngôn ngữ đầu ra'),
          items: ['English', 'Tiếng Việt', '日本語', '한국어', 'Français']
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (s) {
            if (s != null) studio.change(() => studio.language = s);
          },
        ),
        const SizedBox(height: 7),
        Material(
          color: Colors.white,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Yêu cầu lọc tiếng ồn',
              style: TextStyle(fontSize: 11),
            ),
            subtitle: const Text(
              'Tùy chọn cho API sau này',
              style: TextStyle(fontSize: 10, color: muted),
            ),
            value: studio.denoise,
            onChanged: (v) => studio.change(() => studio.denoise = v),
          ),
        ),
        const Text(
          'Hiện chỉ lưu cấu hình. Chưa gọi AI, chưa phát âm thanh.',
          style: TextStyle(fontSize: 10, color: muted, height: 1.6),
        ),
        const SizedBox(height: 18),
        const Divider(color: line),
        const SizedBox(height: 14),
        if (studio.view == 'question') ...[
          sectionLabel('CÂU HỎI MẪU'),
          const SizedBox(height: 12),
          TextField(
            controller: question,
            minLines: 2,
            maxLines: 4,
            onChanged: (v) => studio.change(() => studio.question = v),
            decoration: const InputDecoration(hintText: 'Nội dung câu hỏi…'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bản khung dùng bốn phương án và đáp án B của bài mẫu.',
            style: TextStyle(fontSize: 10, color: muted, height: 1.6),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => studio.change(
              () => studio.reveal = !studio.reveal,
              persist: false,
            ),
            icon: Icon(
              studio.reveal
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 16,
            ),
            label: Text(studio.reveal ? 'Ẩn đáp án' : 'Hiện đáp án'),
          ),
          const SizedBox(height: 16),
        ],
        sectionLabel('GHI CHÚ RIÊNG'),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          minLines: 3,
          maxLines: 5,
          onChanged: (v) => studio.change(() => studio.notes = v),
          decoration: const InputDecoration(
            hintText: 'Điểm cần nhấn mạnh, câu hỏi gợi mở…',
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Không xuất trong khung trình bày.',
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.timer_outlined, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${(studio.seconds ~/ 60).toString().padLeft(2, '0')}:${(studio.seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: studio.timerRunning ? 'Dừng đồng hồ' : 'Bắt đầu 2 phút',
              onPressed: studio.toggleTimer,
              icon: Icon(
                studio.timerRunning
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Bản thử không có lab. Kết nối Meet tự động sẽ phát triển sau.',
          style: TextStyle(fontSize: 10, color: muted, height: 1.6),
        ),
      ],
    ),
  );

  Widget sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w700,
      color: muted,
    ),
  );
  Widget statusLine(IconData icon, String text, String status) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 17, color: muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        Text(
          status,
          style: const TextStyle(fontSize: 10, color: Color(0xff9b7246)),
        ),
      ],
    ),
  );
  Widget pill(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 9,
        letterSpacing: .8,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}
