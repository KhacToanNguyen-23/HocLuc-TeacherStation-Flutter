import 'package:flutter/material.dart';

/// Abstract domain interface for Subject-specific & Exam-oriented plugins.
/// Follows OOP open-closed principle: new plugins extend this class
/// without modifying core Studio code.
abstract class SubjectPlugin {
  /// Unique identifier (e.g. 'org.open.graph_tool', 'org.open.exam_timer')
  String get id;

  /// Display name of the plugin
  String get name;

  /// Short description of the plugin
  String get summary;

  /// Visual icon representing the plugin
  IconData get icon;

  /// Primary accent color for cards and icons
  Color get color => const Color(0xFF0284C7);

  /// Builds the floating widget or dialog interface when active
  Widget buildWidget(BuildContext context);

  /// Optional lifecycle hook called upon installation
  Future<void> onInstall() async {}

  /// Optional lifecycle hook called upon uninstallation
  Future<void> onUninstall() async {}
}
