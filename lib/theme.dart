import 'package:flutter/material.dart';

/// Rail (RepairX) light tokens, mapped onto the existing Workbench layout names.
/// Purple (`--rx-accent`) is reserved for AI and is not used here.
abstract final class Wb {
  static const page = Color(0xFFF9FAFB);
  static const ink = Color(0xFF0F172A);
  static const cream = Color(0xFFFFFFFF);
  static const cream2 = Color(0xFFF8FAFC);
  static const wash = Color(0xFFF1F5F9);
  static const line = Color(0xFFE2E8F0);
  static const line2 = Color(0xFFCBD5E1);
  static const hair = Color(0xFFF1F5F9);
  static const track = Color(0xFFE2E8F0);
  static const muted = Color(0xFF94A3B8);
  static const muted2 = Color(0xFF64748B);
  static const muted3 = Color(0xFF475569);
  static const body = Color(0xFF475569);
  static const tabOff = Color(0xFF64748B);
  static const closed = Color(0xFF94A3B8);
  static const closed2 = Color(0xFFCBD5E1);
  static const emptyDay = Color(0xFFF1F5F9);

  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFEFF6FF);
  static const primaryMuted = Color(0xFF93C5FD);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Overtime / danger — `--rx-error`, not brand purple.
  static const accent = Color(0xFFDC2626);
  static const accentDark = Color(0xFFB91C1C);
  static const accentSoft = Color(0xFFFEE2E2);
  static const accentBorder = Color(0xFFFECACA);
  static const accentBorder2 = Color(0xFFFECACA);
  static const accentHandle = Color(0xFFF87171);

  static const peach = Color(0xFFEFF6FF);
  static const peachHover = Color(0xFFDBEAFE);
  static const peachText = Color(0xFF1D4ED8);
  static const peachBorder = Color(0xFF93C5FD);
  static const peachSel = Color(0xFF2563EB);
  static const peachHeavy = Color(0xFFDBEAFE);

  static const dashed = Color(0xFFDC2626);
  static const coverageRed = Color(0xFFFCA5A5);
  static const coverageGreen = Color(0xFF16A34A);

  static const teal = Color(0xFF2563EB);
  static const info = Color(0xFF3B82F6);
  static const forest = Color(0xFF16A34A);
  static const gold = Color(0xFFC2410C);
  static const purple = Color(0xFF1D4ED8);

  static const shiftBg = Color(0xFFDCFCE7);
  static const shiftBd = Color(0xFFBBF7D0);
  static const shiftFg = Color(0xFF15803D);
  static const shiftHandle = Color(0xFF16A34A);
  static const breakHash = Color(0xFF86EFAC);

  static const toneSuccessBg = Color(0xFFDCFCE7);
  static const toneSuccessFg = Color(0xFF15803D);
  static const toneInfoBg = Color(0xFFDBEAFE);
  static const toneInfoFg = Color(0xFF1D4ED8);
  static const toneNeutralBg = Color(0xFFF1F5F9);
  static const toneNeutralFg = Color(0xFF334155);
  static const toneActiveFg = Color(0xFFC2410C);
  static const toneActiveBg = Color(0xFFFFEDD5);
  static const toneWarningFg = Color(0xFFA16207);
  static const toneWarningBg = Color(0xFFFEF9C3);

  static const double headWidth = 284;
  static const double pad = 18;
  static const double rowH = 56;

  static const double rXs = 4;
  static const double rSm = 6;
  static const double rMd = 8;
  static const double rLg = 12;
  static const double rXl = 16;

  static const sans = 'Inter';
  static const serif = 'Inter';
  static const mono = 'Inter';

  static const scrim = Color(0x660F172A);

  static TextStyle kicker({
    double size = 10.5,
    double tracking = 0.06,
    Color? color,
  }) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * 0.06,
        color: color ?? muted,
        height: 1.2,
      );

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        height: 1.25,
        letterSpacing: size * -0.028,
        color: color ?? ink,
      );

  static TextStyle ui({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? tracking,
    double height = 1.375,
  }) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: tracking ?? -0.014,
        height: height,
      );

  static TextStyle code({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double tracking = -0.014,
  }) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: size * tracking,
        height: 1.25,
      );

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
      ];

  static List<BoxShadow> get overlayShadow => const [
        BoxShadow(color: Color(0x1F0F172A), offset: Offset(0, 20), blurRadius: 25),
        BoxShadow(color: Color(0x1A0F172A), offset: Offset(0, 8), blurRadius: 10),
      ];
}

class JobTone {
  const JobTone({
    required this.label,
    required this.fg,
    required this.bg,
    required this.bd,
    required this.rail,
  });
  final String label;
  final Color fg, bg, bd, rail;
}

abstract final class JobTones {
  static const screen = JobTone(
    label: 'Screen',
    fg: Color(0xFF1D4ED8),
    bg: Color(0xFFDBEAFE),
    bd: Color(0xFF93C5FD),
    rail: Color(0xFF3B82F6),
  );
  static const battery = JobTone(
    label: 'Battery',
    fg: Color(0xFF15803D),
    bg: Color(0xFFDCFCE7),
    bd: Color(0xFFBBF7D0),
    rail: Color(0xFF16A34A),
  );
  static const board = JobTone(
    label: 'Board-level',
    fg: Color(0xFFC2410C),
    bg: Color(0xFFFFEDD5),
    bd: Color(0xFFFDBA74),
    rail: Color(0xFFF97316),
  );
  static const water = JobTone(
    label: 'Water damage',
    fg: Color(0xFFA16207),
    bg: Color(0xFFFEF9C3),
    bd: Color(0xFFFDE047),
    rail: Color(0xFFEAB308),
  );
  static const diag = JobTone(
    label: 'Diagnostics',
    fg: Color(0xFF334155),
    bg: Color(0xFFF1F5F9),
    bd: Color(0xFFCBD5E1),
    rail: Color(0xFF64748B),
  );
}
