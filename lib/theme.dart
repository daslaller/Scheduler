import 'package:flutter/material.dart';

/// Workbench palette from the Schedule Calendar UI mockup.
abstract final class Wb {
  static const page = Color(0xFFF6F3EE);
  static const ink = Color(0xFF1D1C1A);
  static const cream = Color(0xFFFFFDF9);
  static const cream2 = Color(0xFFFBF8F2);
  static const wash = Color(0xFFF0ECE4);
  static const line = Color(0xFFDED7CB);
  static const line2 = Color(0xFFE6E0D5);
  static const hair = Color(0xFFEFEBE2);
  static const track = Color(0xFFEBE5DA);
  static const muted = Color(0xFFA2988A);
  static const muted2 = Color(0xFF8B8175);
  static const muted3 = Color(0xFF6E655A);
  static const body = Color(0xFF4A443C);
  static const tabOff = Color(0xFF7C7466);
  static const closed = Color(0xFFC4BCAE);
  static const closed2 = Color(0xFFCDC5B8);
  static const emptyDay = Color(0xFFF7F4EE);

  static const accent = Color(0xFFB4432B);
  static const accentDark = Color(0xFF8E3320);
  static const accentSoft = Color(0xFFFBEAE4);
  static const accentBorder = Color(0xFFE2B7A8);
  static const accentBorder2 = Color(0xFFEBC8BC);
  static const accentHandle = Color(0xFFC98A78);
  static const peach = Color(0xFFFBF0E6);
  static const peachHover = Color(0xFFF6E3D2);
  static const peachText = Color(0xFF96421F);
  static const peachBorder = Color(0xFFE2C9B4);
  static const peachSel = Color(0xFFD9A97F);
  static const peachHeavy = Color(0xFFEBD3CB);
  static const dashed = Color(0xFFC9836A);
  static const coverageRed = Color(0xFFDFA894);
  static const coverageGreen = Color(0xFF4C9670);

  static const teal = Color(0xFF2E7D9E);
  static const forest = Color(0xFF3E8A64);
  static const gold = Color(0xFFC07A22);
  static const purple = Color(0xFF6B52A3);
  static const shiftBg = Color(0xFFEAF1EC);
  static const shiftBd = Color(0xFFBFD6C6);
  static const shiftFg = Color(0xFF2C5A44);
  static const shiftHandle = Color(0xFF8FB7A0);
  static const breakHash = Color(0xFFB9CFC1);

  static const double headWidth = 284;
  static const double pad = 18;
  static const double rowH = 56;

  static const sans = 'Work Sans';
  static const serif = 'Instrument Serif';
  static const mono = 'IBM Plex Mono';

  static TextStyle kicker({double size = 10.5, double tracking = 0.16}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: size * tracking,
        color: muted,
        height: 1.2,
      );

  static TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: weight,
        height: 1.04,
        letterSpacing: size * -0.02,
        color: color ?? ink,
      );

  static TextStyle ui({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? tracking,
    double height = 1.2,
  }) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: tracking ?? 0,
        height: height,
      );

  static TextStyle code({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double tracking = -0.02,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: size * tracking,
        height: 1.15,
      );

  static List<BoxShadow> get cardShadow => const [
        BoxShadow(color: Color(0x0D1D1C1A), offset: Offset(0, 1), blurRadius: 2),
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
    fg: Color(0xFF1F5E7A),
    bg: Color(0xFFE4F0F5),
    bd: Color(0xFFBFDCE7),
    rail: Color(0xFF2E7D9E),
  );
  static const battery = JobTone(
    label: 'Battery',
    fg: Color(0xFF2C6047),
    bg: Color(0xFFE5F1E9),
    bd: Color(0xFFC4E0CF),
    rail: Color(0xFF3E8A64),
  );
  static const board = JobTone(
    label: 'Board-level',
    fg: Color(0xFF4C3A73),
    bg: Color(0xFFEDE8F5),
    bd: Color(0xFFD6CCE9),
    rail: Color(0xFF6B52A3),
  );
  static const water = JobTone(
    label: 'Water damage',
    fg: Color(0xFF8A5216),
    bg: Color(0xFFFBF0DF),
    bd: Color(0xFFEBD6B4),
    rail: Color(0xFFC07A22),
  );
  static const diag = JobTone(
    label: 'Diagnostics',
    fg: Color(0xFF5C564C),
    bg: Color(0xFFF0ECE4),
    bd: Color(0xFFDED7CB),
    rail: Color(0xFF8B8175),
  );
}
