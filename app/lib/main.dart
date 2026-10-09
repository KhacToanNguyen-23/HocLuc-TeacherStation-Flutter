import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models/studio_state.dart';
import 'widgets/flat_host.dart';

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
  bool flat = false;
  bool initializedControllers = false;
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
    if (flat) {
      message(
        'Preview khung Flutter hiện hỗ trợ bảng nháp và câu hỏi. Capture bảng Flat cần adapter tiếp theo.',
      );
      return;
    }
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
            final wide = box.maxWidth >= 1250,
                showLessons = box.maxWidth >= 1000;
            return Row(
              children: [
                rail(),
                Expanded(
                  child: Column(
                    children: [
                      header(box.maxWidth),
                      if (studio.error != null && !studio.online)
                        Container(
                          color: const Color(0xffffeed9),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  studio.error!,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              TextButton(
                                onPressed: studio.loading
                                    ? null
                                    : () {
                                        initializedControllers = false;
                                        studio.initialize();
                                      },
                                child: const Text('Kết nối lại'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Row(
                          children: [
                            if (showLessons)
                              SizedBox(width: 220, child: lessons()),
                            Expanded(
                              child: Column(
                                children: [
                                  canvasHeader(showLessons, wide),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        4,
                                        24,
                                        12,
                                      ),
                                      child: Stack(
                                        children: [
                                          if (flat)
                                            Positioned.fill(
                                              child: Offstage(
                                                offstage:
                                                    studio.view != 'board',
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: FlatHost(
                                                    key: const ValueKey(
                                                      'flat-board',
                                                    ),
                                                    url:
                                                        '${studio.service.base}/flat/',
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Positioned.fill(
                                            child: Offstage(
                                              offstage:
                                                  flat &&
                                                  studio.view == 'board',
                                              child: fittedStage(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!flat && studio.view == 'board')
                                    drawingToolbar(),
                                  footer(),
                                ],
                              ),
                            ),
                            if (wide) SizedBox(width: 304, child: inspector()),
                          ],
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

  Widget rail() => Container(
    width: 72,
    color: pine,
    child: Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: lime,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Center(
            child: Text(
              'm',
              style: TextStyle(
                fontFamily: 'Literata',
                fontSize: 31,
                fontWeight: FontWeight.bold,
                color: pine,
              ),
            ),
          ),
        ),
        const SizedBox(height: 42),
        railItem(Icons.dashboard_outlined, 'Bảng giảng', 'board'),
        railItem(Icons.quiz_outlined, 'Câu hỏi', 'question'),
        const Spacer(),
        IconButton(
          tooltip: 'Thiết bị và API AI',
          onPressed: openInspector,
          icon: const Icon(Icons.tune, color: Color(0xffb7cbc1)),
        ),
        const SizedBox(height: 16),
        const CircleAvatar(
          radius: 16,
          backgroundColor: Color(0xff34574c),
          child: Text(
            'GV',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
        const SizedBox(height: 22),
      ],
    ),
  );
  Widget railItem(IconData icon, String label, String mode) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: () => studio.setView(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: studio.view == mode
                ? const Color(0xff325a4b)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: studio.view == mode ? lime : const Color(0xffa1b7ac),
            size: 23,
          ),
        ),
      ),
    ),
  );

  Widget header(double width) => Container(
    height: 82,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'MỘC / TEACHING STUDIO',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      studio.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đổi tên bài giảng',
                    onPressed: rename,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (width > 1000) ...[
          pill('BẢN KHUNG 0.1', const Color(0xffedf2e5), pine),
          const SizedBox(width: 18),
        ],
        IconButton(
          tooltip: 'Xem khung trình bày',
          onPressed: preview,
          icon: const Icon(Icons.slideshow_outlined),
        ),
        const SizedBox(width: 8),
        if (width > 650)
          FilledButton.icon(
            onPressed: studio.saving || studio.loading ? null : save,
            icon: const Icon(Icons.save_outlined, size: 17),
            label: Text(studio.saving ? 'Đang lưu…' : 'Lưu bài'),
          )
        else
          IconButton(
            tooltip: 'Lưu bài',
            onPressed: studio.saving ? null : save,
            icon: const Icon(Icons.save_outlined),
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
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 6),
        const Text(
          'BÀI GIẢNG',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: studio.subject,
          isExpanded: true,
          items: ['Toán học', 'Vật lí', 'Hóa học', 'Sinh học']
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
          onChanged: (s) {
            if (s != null) studio.change(() => studio.subject = s);
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'Nội dung buổi dạy',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 12),
        for (final (index, label) in [
          (0, 'Khám phá hàm số'),
          (1, 'Giải thích trên bảng'),
          (2, 'Luyện tập'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => studio.change(() {
                studio.page = index;
                studio.view = 'board';
              }),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: studio.page == index && studio.view == 'board'
                      ? const Color(0xfff0f4e8)
                      : Colors.white,
                  border: Border.all(
                    color: studio.page == index && studio.view == 'board'
                        ? const Color(0xffadc38c)
                        : line,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '0${index + 1}',
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        const Spacer(),
                        Icon(
                          index == 0 ? Icons.show_chart : Icons.draw_outlined,
                          size: 15,
                          color: muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      index == 0
                          ? 'Học liệu mẫu · bảng nháp'
                          : '${studio.pages[index].length} nét vẽ',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => studio.setView('question'),
          icon: const Icon(Icons.quiz_outlined, size: 16),
          label: const Text('Đặt câu hỏi', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 26),
        const Text(
          'DẠY QUA MEET',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.3,
            color: muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Học sinh chỉ dùng meeting. Kết nối thu đáp án tự động chưa được triển khai.',
          style: TextStyle(fontSize: 11, color: muted, height: 1.7),
        ),
      ],
    ),
  );

  Widget canvasHeader(bool showLessons, bool wide) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
    child: Row(
      children: [
        if (!showLessons)
          IconButton(
            tooltip: 'Nội dung bài giảng',
            onPressed: openLessons,
            icon: const Icon(Icons.view_sidebar_outlined, size: 19),
          ),
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.circle, size: 6, color: muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  studio.view == 'question'
                      ? 'Câu hỏi cho cả lớp'
                      : flat
                      ? 'Whiteboard Flat'
                      : 'Không gian giảng bài',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (studio.view == 'board')
          TextButton(
            onPressed: () => setState(() => flat = !flat),
            child: Text(
              flat ? 'Bảng nháp' : 'Mở Flat',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        if (!wide)
          IconButton(
            tooltip: 'Thiết bị và ghi chú',
            onPressed: openInspector,
            icon: const Icon(Icons.tune, size: 19),
          ),
      ],
    ),
  );

  Widget fittedStage({bool interactive = true}) => LayoutBuilder(
    builder: (context, constraints) {
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
              color: const Color(0xfffffef8),
              child: studio.view == 'question'
                  ? questionStage()
                  : boardStage(interactive),
            ),
          ),
        ),
      );
    },
  );

  Widget boardStage(bool interactive) => LayoutBuilder(
    builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      Offset normalized(Offset p) => Offset(
        (p.dx / size.width).clamp(0, 1),
        (p.dy / size.height).clamp(0, 1),
      );
      return GestureDetector(
        onPanStart: interactive
            ? (e) => studio.startStroke(normalized(e.localPosition))
            : null,
        onPanUpdate: interactive
            ? (e) => studio.extendStroke(normalized(e.localPosition))
            : null,
        onTapUp: interactive
            ? (e) => studio.startStroke(normalized(e.localPosition))
            : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: BoardPainter(studio.strokes, graph: studio.page == 0),
              ),
            ),
            Positioned(
              left: box.maxWidth * .055,
              top: box.maxHeight * .08,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${studio.subject.toUpperCase()} / 0${studio.page + 1}',
                      style: TextStyle(
                        fontSize: box.maxWidth * .015,
                        letterSpacing: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      studio.page == 0
                          ? 'Một đường cong, nhiều điều để khám phá.'
                          : studio.page == 1
                          ? 'Cùng giải thích.'
                          : 'Thử một cách giải khác.',
                      style: TextStyle(
                        fontFamily: 'Literata',
                        fontSize: box.maxWidth * .029,
                        color: pine,
                      ),
                    ),
                    if (studio.page == 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'y = x² − 2x − 3',
                        style: TextStyle(
                          fontSize: box.maxWidth * .032,
                          color: pine,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (studio.page == 0)
              Positioned(
                left: box.maxWidth * .06,
                bottom: box.maxHeight * .16,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HÃY QUAN SÁT',
                        style: TextStyle(
                          fontSize: box.maxWidth * .012,
                          letterSpacing: 1.5,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'Đỉnh ở đâu?\nĐồ thị cắt trục Ox tại điểm nào?',
                        style: TextStyle(
                          fontSize: box.maxWidth * .017,
                          height: 1.8,
                          color: pine,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 12,
              right: 16,
              child: Text(
                'BẢNG NHÁP DEMO · KHÔNG PHẢI FLAT',
                style: TextStyle(
                  fontSize: math.max(7, box.maxWidth * .009),
                  color: muted,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

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
    padding: const EdgeInsets.only(bottom: 18),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
            for (final color in [
              pine,
              const Color(0xffb95b3b),
              const Color(0xff517bb0),
            ])
              Tooltip(
                message:
                    'Chọn màu ${color == pine
                        ? 'xanh lá'
                        : color == const Color(0xffb95b3b)
                        ? 'cam'
                        : 'xanh dương'}',
                child: InkWell(
                  onTap: () =>
                      studio.change(() => studio.ink = color, persist: false),
                  child: Container(
                    width: 25,
                    height: 25,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: studio.ink == color
                            ? const Color(0xffc2cfac)
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Hoàn tác nét',
              onPressed: studio.strokes.isEmpty ? null : studio.undo,
              icon: const Icon(Icons.undo, size: 19),
            ),
            IconButton(
              tooltip: 'Xóa nét trang này',
              onPressed: studio.strokes.isEmpty ? null : studio.clearPage,
              icon: const Icon(Icons.delete_outline, size: 19),
            ),
          ],
        ),
      ),
    ),
  );

  Widget footer() => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.circle,
          size: 6,
          color: studio.online
              ? const Color(0xff68934b)
              : const Color(0xffbc8d52),
        ),
        const SizedBox(width: 7),
        Text(
          studio.online ? 'Java đã kết nối' : 'Chưa kết nối Java',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const Spacer(),
        Text(
          studio.dirty
              ? 'Có thay đổi chưa lưu'
              : studio.savedAt.isNotEmpty
              ? 'Đã lưu ${studio.savedAt}'
              : 'Bài giảng trên máy',
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(width: 14),
        const Text('16:9', style: TextStyle(fontSize: 10, color: muted)),
      ],
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

class BoardPainter extends CustomPainter {
  BoardPainter(this.strokes, {this.graph = false});
  final List<BoardStroke> strokes;
  final bool graph;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xffe4e7da);
    for (double x = 20; x < size.width; x += 22) {
      for (double y = 20; y < size.height; y += 22) {
        canvas.drawCircle(Offset(x, y), .65, grid);
      }
    }
    if (graph) {
      final origin = Offset(size.width * .72, size.height * .50);
      final unit = size.height * .059;
      final axes = Paint()
        ..color = const Color(0xff9eaca0)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(size.width * .47, origin.dy),
        Offset(size.width * .95, origin.dy),
        axes,
      );
      canvas.drawLine(
        Offset(origin.dx, size.height * .18),
        Offset(origin.dx, size.height * .88),
        axes,
      );
      for (int i = -3; i <= 3; i++) {
        canvas.drawLine(
          origin + Offset(i * unit, -3),
          origin + Offset(i * unit, 3),
          axes,
        );
      }
      final curve = Path();
      bool first = true;
      for (double x = -2.3; x <= 4.2; x += .025) {
        final y = x * x - 2 * x - 3;
        final point = origin + Offset(x * unit, -y * unit);
        if (point.dy < size.height * .20 || point.dy > size.height * .9) {
          first = true;
          continue;
        }
        if (first) {
          curve.moveTo(point.dx, point.dy);
          first = false;
        } else {
          curve.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        curve,
        Paint()
          ..color = pine
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        origin + Offset(unit, 4 * unit),
        4,
        Paint()..color = const Color(0xffbd6947),
      );
      final label = TextPainter(
        text: const TextSpan(
          text: 'I (1; −4)',
          style: TextStyle(
            fontFamily: 'Manrope',
            color: Color(0xffbd6947),
            fontSize: 11,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, origin + Offset(unit + 10, 4 * unit - 8));
    }
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.width > 3
            ? stroke.color.withValues(alpha: .3)
            : stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          at(stroke.points.first),
          stroke.width / 2,
          Paint()..color = paint.color,
        );
        continue;
      }
      final path = Path()
        ..moveTo(at(stroke.points.first).dx, at(stroke.points.first).dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(at(point).dx, at(point).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
