import 'package:flutter/material.dart';

/// HocLuc web palette shared by Teacher Station chrome. Drawing/PDF content is independent.
abstract final class AppPalette {
  static const primary = Color(0xFF0B3A82);
  static const primaryHover = Color(0xFF082F6B);
  static const primaryPressed = Color(0xFF062653);
  static const onPrimary = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceInput = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF6F9FF);
  static const surfaceMuted = surfaceSoft;
  static const textPrimary = Color(0xFF0B2348);
  static const textSecondary = Color(0xFF526984);
  static const textMuted = Color(0xFF60758F);
  static const textFaint = Color(0xFF60758F);
  static const textDim = Color(0xFF526984);
  static const textHeadingMuted = Color(0xFF365576);
  static const border = Color(0xFFC4D6EC);
  static const surfaceBorder = Color(0xFFD6E3F2);
  static const inputBorder = Color(0xFF60758F);
  static const selected = Color(0xFFEDF5FF);
  static const onSelected = primary;
  static const accentDark = Color(0xFF0B3A82);
  static const sky = Color(0xFF1E88FF);
  static const shellSidebar = Color(0xFFFFFFFF);
  static const shellSidebarText = Color(0xFF0B2348);
  static const shellSidebarMuted = Color(0xFF526984);
  static const shellSidebarActive = Color(0xFFEDF5FF);
  static const lock = Color(0xFF60758F);
  static const lockSoft = Color(0xFFF0F4FA);
  static const streak = Color(0xFF965600);
  static const streakSoft = Color(0xFFFFF6E8);
  static const skeletonHighlight = Color(0xFFF8FAFF);
  static const scrollbarTrack = Color(0xFFF6F9FF);
  static const scrollbarThumb = Color(0xFFC4D6EC);
  static const success = Color(0xFF047857);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFF92400E);
  static const warningSurface = Color(0xFFFFFBEB);
  static const error = Color(0xFFB91C1C);
  static const errorSurface = Color(0xFFFFF1F2);
}
