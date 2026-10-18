import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/services/smart_pen_answer_index.dart';
import 'smart_pen_profile_report_stub.dart'
    if (dart.library.js_interop) 'smart_pen_profile_report_web.dart'
    as profile_report;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartPenProfileApp());
}

class SmartPenProfileApp extends StatefulWidget {
  const SmartPenProfileApp({super.key});

  @override
  State<SmartPenProfileApp> createState() => _SmartPenProfileAppState();
}

class _SmartPenProfileAppState extends State<SmartPenProfileApp> {
  String _status = 'Starting Smart Pen profile workload…';
  int _frame = 0;
  Timer? _frameTimer;
  final _timings = <FrameTiming>[];
  final _timerIntervals = <_TimerInterval>[];
  final _elapsedClock = Stopwatch();
  var _previousTimerTick = 0;
  int? _frameClockOffsetUs;
  int? _indexStartUs;
  int? _indexEndUs;
  int? _drainEndUs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runProfile());
  }

  Future<void> _runProfile() async {
    final binding = WidgetsBinding.instance;
    await pdfrx.pdfrxFlutterInitialize();
    final pdf = await pdfrx.PdfDocument.openData(
      _makeIndexWorkloadPdf(),
      useProgressiveLoading: false,
      sourceName: 'smart-pen-runtime-profile.pdf',
    );
    binding.addTimingsCallback(_collectFrameTimings);
    _elapsedClock.start();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _elapsedClock.elapsedMicroseconds;
      _timerIntervals.add(_TimerInterval(_previousTimerTick, now));
      _previousTimerTick = now;
      if (mounted) setState(() => _frame++);
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      setState(() => _status = 'Extracting and indexing one visible page…');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      _indexStartUs = _elapsedClock.elapsedMicroseconds;
      final stopwatch = Stopwatch()..start();
      final extractionStopwatch = Stopwatch()..start();
      final fragments = await SmartPenPdfTextExtractor().extract(
        pdf.pages.first,
      );
      extractionStopwatch.stop();
      final classificationStopwatch = Stopwatch()..start();
      final index = SmartPenPageIndex.build(
        documentGeneration: 1,
        pageNumber: 1,
        pageSize: SmartPenPdfTextExtractor.canonicalPageSize(pdf.pages.first),
        fragments: fragments,
      );
      classificationStopwatch.stop();
      stopwatch.stop();
      _indexEndUs = _elapsedClock.elapsedMicroseconds;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _drainEndUs = _elapsedClock.elapsedMicroseconds;
      final metrics = _metrics(
        elapsed: stopwatch.elapsed,
        extractionElapsed: extractionStopwatch.elapsed,
        classificationElapsed: classificationStopwatch.elapsed,
        fragments: fragments.length,
        candidates: index.candidates.length,
      );
      final report = jsonEncode(metrics);
      debugPrint('SMART_PEN_RUNTIME_PROFILE=$report');
      profile_report.publishProfileMetrics(report);
      if (mounted) {
        setState(() => _status = jsonEncode(metrics));
      }
    } catch (error, stackTrace) {
      debugPrint('SMART_PEN_RUNTIME_PROFILE_ERROR=$error\n$stackTrace');
      if (mounted) setState(() => _status = 'Profile error: $error');
    } finally {
      await pdf.dispose();
      _frameTimer?.cancel();
      binding.removeTimingsCallback(_collectFrameTimings);
    }
  }

  void _collectFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameClockOffsetUs ??=
          _elapsedClock.elapsedMicroseconds -
          timing.timestampInMicroseconds(FramePhase.rasterFinish);
      _timings.add(timing);
    }
  }

  Map<String, Object> _metrics({
    required Duration elapsed,
    required Duration extractionElapsed,
    required Duration classificationElapsed,
    required int fragments,
    required int candidates,
  }) {
    final indexFrames = _framesIn(_indexStartUs!, _indexEndUs!);
    final drainFrames = _framesIn(_indexEndUs!, _drainEndUs!);
    final nonIndexFrames = _timings
        .where((frame) => !_isInWindow(frame, _indexStartUs!, _drainEndUs!))
        .toList();
    final indexIntervals = _intervalsOverlapping(_indexStartUs!, _indexEndUs!);
    final drainIntervals = _intervalsOverlapping(_indexEndUs!, _drainEndUs!);

    return {
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'indexMs': elapsed.inMilliseconds,
      'extractionMs': extractionElapsed.inMilliseconds,
      'classificationMs': classificationElapsed.inMilliseconds,
      'fragments': fragments,
      'candidates': candidates,
      'nonIndexFrameSamples': nonIndexFrames.length,
      'indexFrameSamples': indexFrames.length,
      'indexDrainFrameSamples': drainFrames.length,
      'nonIndexBuildP95Us': _frameP95(
        nonIndexFrames,
        (frame) => frame.buildDuration,
      ),
      'indexBuildP95Us': _frameP95(indexFrames, (frame) => frame.buildDuration),
      'nonIndexRasterP95Us': _frameP95(
        nonIndexFrames,
        (frame) => frame.rasterDuration,
      ),
      'indexRasterP95Us': _frameP95(
        indexFrames,
        (frame) => frame.rasterDuration,
      ),
      'indexDrainBuildP95Us': _frameP95(
        drainFrames,
        (frame) => frame.buildDuration,
      ),
      'indexDrainRasterP95Us': _frameP95(
        drainFrames,
        (frame) => frame.rasterDuration,
      ),
      'indexTimerOverlapSamples': indexIntervals.length,
      'indexOverlappingTimerGapMaxUs': _maximumInterval(indexIntervals),
      'indexOverlappingTimerGapsOver16_7ms': indexIntervals
          .where((interval) => interval.durationUs > 16667)
          .length,
      'drainTimerOverlapSamples': drainIntervals.length,
      'drainOverlappingTimerGapMaxUs': _maximumInterval(drainIntervals),
      'drainOverlappingTimerGapsOver16_7ms': drainIntervals
          .where((interval) => interval.durationUs > 16667)
          .length,
    };
  }

  List<FrameTiming> _framesIn(int startUs, int endUs) =>
      _timings.where((frame) => _isInWindow(frame, startUs, endUs)).toList();

  bool _isInWindow(FrameTiming frame, int startUs, int endUs) {
    final offset = _frameClockOffsetUs;
    if (offset == null) return false;
    final frameStartUs =
        frame.timestampInMicroseconds(FramePhase.vsyncStart) + offset;
    return frameStartUs >= startUs && frameStartUs < endUs;
  }

  List<_TimerInterval> _intervalsOverlapping(int startUs, int endUs) =>
      _timerIntervals
          .where(
            (interval) => interval.startUs < endUs && interval.endUs > startUs,
          )
          .toList();

  int _maximumInterval(List<_TimerInterval> intervals) => intervals.fold<int>(
    0,
    (maximum, interval) =>
        interval.durationUs > maximum ? interval.durationUs : maximum,
  );

  int _frameP95(
    List<FrameTiming> timings,
    Duration Function(FrameTiming) durationOf,
  ) => _intP95(timings.map((timing) => durationOf(timing).inMicroseconds));

  int _intP95(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return 0;
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('Frame $_frame\n$_status'),
        ),
      ),
    ),
  );
}

class _TimerInterval {
  const _TimerInterval(this.startUs, this.endUs);

  final int startUs;
  final int endUs;

  int get durationUs => endUs - startUs;
}

Uint8List _makeIndexWorkloadPdf() {
  final pdf = sf.PdfDocument()..pageSettings.size = const Size(612, 10000);
  final page = pdf.pages.add();
  final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 8);
  final markerBrush = sf.PdfSolidBrush(sf.PdfColor(20, 20, 20));
  final textBrush = sf.PdfSolidBrush(sf.PdfColor(60, 60, 60));
  for (var row = 0; row < 320; row++) {
    final y = 24.0 + (row ~/ 4) * 120 + (row % 4) * 24;
    final label = String.fromCharCode(65 + row % 4);
    page.graphics.drawString(
      '$label.',
      font,
      brush: markerBrush,
      bounds: Rect.fromLTWH(40, y, 20, 12),
    );
    page.graphics.drawString(
      'Option ${row + 1} sample answer text',
      font,
      brush: textBrush,
      bounds: Rect.fromLTWH(64, y, 240, 12),
    );
  }
  final bytes = Uint8List.fromList(pdf.saveSync());
  pdf.dispose();
  return bytes;
}
