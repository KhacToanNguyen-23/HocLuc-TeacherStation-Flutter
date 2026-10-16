import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/theme/app_theme.dart';
import 'package:teaching_companion/models/planning_meta.dart';
import 'package:teaching_companion/widgets/dashboard/planning_list_card.dart';
import 'package:teaching_companion/widgets/dashboard/dashboard_action_card.dart';
import 'package:teaching_companion/widgets/grid_painter.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  testWidgets(
    'real lesson action inherits visible hover and pressed feedback',
    (tester) async {
      var launched = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1000,
                height: 400,
                child: PlanningListCard(
                  plannings: [
                    PlanningMeta(
                      id: 'fixture',
                      title: 'Bài giảng kiểm tra',
                      subject: 'Toán',
                      pageCount: 1,
                      createdAt: 0,
                      updatedAt: 0,
                    ),
                  ],
                  isLoading: false,
                  selectedSubject: 'Tất cả',
                  subjectOptions: const ['Tất cả'],
                  onSubjectChanged: (_) {},
                  onCreateNew: () {},
                  onEdit: (_) {},
                  onLaunch: (_) => launched++,
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final button = find.widgetWithText(ElevatedButton, 'Dạy ngay');
      Color? fill() => tester
          .widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)).first,
          )
          .color;
      final rect = tester.getRect(button);
      expect(fill(), AppColors.primary);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(rect.center);
      await tester.pumpAndSettle();
      expect(fill(), AppColors.primaryHover);
      await mouse.down(rect.center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(fill(), AppColors.primaryPressed);
      expect(tester.getRect(button), rect);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(launched, 1);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'reading and status colors meet contrast across their actual surfaces',
    () {
      for (final pair in [
        (AppColors.onPrimary, AppColors.primary),
        (AppColors.onPrimary, AppColors.primaryHover),
        (AppColors.onPrimary, AppColors.primaryPressed),
        (AppColors.onPrimary, AppColors.textMuted),
        (AppColors.textPrimary, AppColors.surface),
        (AppColors.textSecondary, AppColors.background),
        (AppColors.textMuted, AppColors.background),
        (AppColors.textMuted, AppColors.surface),
        (AppColors.onSelected, AppColors.selected),
        (AppColors.success, AppColors.successSurface),
        (AppColors.warning, AppColors.warningSurface),
        (AppColors.error, AppColors.errorSurface),
        (AppColors.overlayMuted, AppColors.overlaySurface),
        (AppColors.overlayMuted, AppColors.overlayRaised),
        (AppColors.overlayAccent, AppColors.overlaySelected),
        (AppColors.rose100, AppColors.overlayRaised),
        (AppColors.emerald100, AppColors.overlaySelected),
        (AppColors.amber100, AppColors.overlayRaised),
      ]) {
        expect(
          _contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '${pair.$1} on ${pair.$2}',
        );
      }
      expect(
        _contrast(AppColors.inputBorder, AppColors.surface),
        greaterThanOrEqualTo(3),
      );
      // The board/ink belongs to teaching content, independently of app chrome.
      expect(chalkboardBg, const Color(0xFF14221D));
      expect(_contrast(const Color(0xFFF0F3ED), chalkboardBg), greaterThan(7));
    },
  );

  testWidgets(
    'action cards work with keyboard and pointer without moving the target',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DashboardActionCard(
                  title: 'Bắt đầu',
                  icon: Icons.videocam_outlined,
                  onTap: () => activated++,
                ),
              ),
            ),
          ),
        ),
      );
      final finder = find.byType(DashboardActionCard);
      final before = tester.getRect(finder);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(activated, 1);
      expect(tester.getRect(finder), before);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(before.center);
      await tester.pumpAndSettle();
      expect(tester.getRect(finder), before);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(activated, 2);
      expect(tester.getRect(finder), before);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion gives immediate card feedback with the same geometry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(reduceMotion: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: DashboardActionCard(
                  title: 'Tham gia',
                  icon: Icons.add_link,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final finder = find.byType(DashboardActionCard);
      final rect = tester.getRect(finder);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(rect.center);
      await tester.pump();
      for (final widget in tester.widgetList<AnimatedContainer>(
        find.descendant(of: finder, matching: find.byType(AnimatedContainer)),
      )) {
        expect(widget.duration, Duration.zero);
      }
      expect(tester.getRect(finder), rect);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
