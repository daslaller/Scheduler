import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

const kDayStart = 7.5;
const kDayEnd = 19.0;
const kDaySpan = kDayEnd - kDayStart;
const kNowHour = 13.75;
const kYear = 2026;

const kDayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
const kMonNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const kDowNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

enum JobKind { screen, battery, board, water, diag }

enum TimelineView { clock, repairs }

enum SheetTab { clock, work }

enum MonthMode { hours, crew, status }

enum ApprovalStatus { approved, submitted, draft, closed }

JobTone toneOf(JobKind k) => switch (k) {
      JobKind.screen => JobTones.screen,
      JobKind.battery => JobTones.battery,
      JobKind.board => JobTones.board,
      JobKind.water => JobTones.water,
      JobKind.diag => JobTones.diag,
    };

class Worker {
  const Worker({
    required this.name,
    required this.role,
    required this.initial,
    required this.cert,
    required this.tint,
    required this.clockIn,
    required this.clockOut,
    required this.breakAt,
  });

  final String name, role, initial, cert;
  final Color tint;
  final double clockIn, clockOut, breakAt;
}

class JobSeed {
  const JobSeed({
    required this.title,
    required this.kind,
    required this.start,
    required this.duration,
    required this.rate,
  });
  final String title;
  final JobKind kind;
  final double start, duration, rate;
}

class RepairJob {
  const RepairJob({
    required this.title,
    required this.kind,
    required this.start,
    required this.duration,
    required this.rate,
  });
  final String title;
  final JobKind kind;
  final double start, duration, rate;
  double get end => start + duration;
}

class ClockHours {
  const ClockHours({required this.inHour, required this.outHour, required this.breakAt});
  final double inHour, outHour, breakAt;
  double get paid => outHour - inHour;
  bool get overtime => paid > 8;
  bool get hasBreak => breakAt > 0;
}

class DayMeta {
  const DayMeta({
    required this.day,
    required this.crewN,
    required this.perTech,
    required this.hours,
    required this.ot,
    required this.status,
  });
  final int day, crewN;
  final List<double> perTech;
  final double hours, ot;
  final ApprovalStatus status;
}

class StatTile {
  const StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
    required this.dot,
    required this.bar,
    this.valueColor,
  });
  final String label, value, unit, sub;
  final Color dot, bar;
  final Color? valueColor;
}

const workers = [
  Worker(
    name: 'Alex Kim (you)',
    role: 'Lead Tech',
    initial: 'AK',
    cert: 'Board L3',
    tint: Color(0xFFB4432B),
    clockIn: 13,
    clockOut: 19,
    breakAt: 16,
  ),
  Worker(
    name: 'Priya Raman',
    role: 'Micro-solder',
    initial: 'PR',
    cert: 'IPC-7711',
    tint: Color(0xFF6B52A3),
    clockIn: 8,
    clockOut: 16.5,
    breakAt: 12,
  ),
  Worker(
    name: 'Rufus Mbeki',
    role: 'Screen Bench',
    initial: 'RM',
    cert: 'OEM Cert',
    tint: Color(0xFF2E7D9E),
    clockIn: 10,
    clockOut: 17,
    breakAt: 13,
  ),
  Worker(
    name: 'Tobias Lund',
    role: 'Diagnostics',
    initial: 'TL',
    cert: 'Level 2',
    tint: Color(0xFF3E8A64),
    clockIn: 12,
    clockOut: 17,
    breakAt: 14.5,
  ),
  Worker(
    name: 'Benjamin Hale',
    role: 'Apprentice',
    initial: 'BH',
    cert: 'Year 2',
    tint: Color(0xFFC0447A),
    clockIn: 10,
    clockOut: 13,
    breakAt: 0,
  ),
  Worker(
    name: 'Nina Castel',
    role: 'QC / Intake',
    initial: 'NC',
    cert: 'QA Lead',
    tint: Color(0xFFC07A22),
    clockIn: 9,
    clockOut: 14,
    breakAt: 11.5,
  ),
  Worker(
    name: 'Tom Braddock',
    role: 'Data Recovery',
    initial: 'TB',
    cert: 'Chip-off',
    tint: Color(0xFF1F7A80),
    clockIn: 11,
    clockOut: 19,
    breakAt: 15,
  ),
];

const jobSeeds = <List<JobSeed>>[
  [
    JobSeed(title: 'iPhone 14 Pro · glass', kind: JobKind.screen, start: 8, duration: 2.5, rate: 95),
    JobSeed(title: 'Pixel 8 · board rework', kind: JobKind.board, start: 11, duration: 3.5, rate: 140),
    JobSeed(title: 'Intake triage', kind: JobKind.diag, start: 15, duration: 1.5, rate: 70),
  ],
  [
    JobSeed(title: 'MacBook A2338 · CPU line', kind: JobKind.board, start: 8.5, duration: 4, rate: 150),
    JobSeed(title: 'S23 · charge port', kind: JobKind.board, start: 13, duration: 2.5, rate: 120),
  ],
  [
    JobSeed(title: 'iPad 9 · digitizer ×3', kind: JobKind.screen, start: 8, duration: 4.5, rate: 88),
    JobSeed(title: 'iPhone 12 · LCD swap', kind: JobKind.screen, start: 13.5, duration: 2, rate: 88),
  ],
  [
    JobSeed(title: 'Warranty diagnostics', kind: JobKind.diag, start: 9, duration: 3, rate: 70),
    JobSeed(title: 'S22 Ultra · liquid', kind: JobKind.water, start: 12.5, duration: 3.5, rate: 110),
  ],
  [
    JobSeed(title: 'Battery bench · 6 units', kind: JobKind.battery, start: 8, duration: 3.5, rate: 60),
    JobSeed(title: 'Pixel 7a · battery', kind: JobKind.battery, start: 12, duration: 1.5, rate: 60),
  ],
  [
    JobSeed(title: 'QC pass · outbound', kind: JobKind.diag, start: 8.5, duration: 2, rate: 75),
    JobSeed(title: 'iPhone 13 · water rescue', kind: JobKind.water, start: 11, duration: 4.5, rate: 110),
  ],
  [
    JobSeed(title: 'Chip-off recovery', kind: JobKind.board, start: 9.5, duration: 5, rate: 165),
    JobSeed(title: 'Client handover', kind: JobKind.diag, start: 15, duration: 1, rate: 75),
  ],
];

/// 12-hour clock label matching the mockup (`1:45p`, `8a`).
String formatHour(double h, {bool amPm = false}) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  final ap = hh >= 12 ? (amPm ? 'pm' : 'p') : (amPm ? 'am' : 'a');
  final d = hh % 12 == 0 ? 12 : hh % 12;
  final mins = mm == 0 ? '' : ':${mm.toString().padLeft(2, '0')}';
  return '$d$mins$ap';
}

double hourToPct(double h) => (h - kDayStart) / kDaySpan;

double jitter(int day, int worker, int job) =>
    math.sin((day + 1) * (worker + 2) * (job + 3) * 1.7);

List<RepairJob> repairJobsFor(int workerIndex, int day, double clockIn) {
  final out = <RepairJob>[];
  var t = clockIn + 0.5;
  final seeds = jobSeeds[workerIndex];
  for (var j = 0; j < seeds.length; j++) {
    final b = seeds[j];
    final jt = jitter(day, workerIndex, j);
    if (jt < -0.6) continue;
    if (t >= kDayEnd - 0.75) continue;
    final dur = math.max(
      1.0,
      math.min(4.5, math.min(kDayEnd - t, b.duration + jt.round() / 2)),
    );
    out.add(RepairJob(title: b.title, kind: b.kind, start: t, duration: dur, rate: b.rate));
    t += dur + 0.5;
  }
  return out;
}

DayMeta dayMeta(int month, int day) {
  final dow = DateTime(kYear, month + 1, day).weekday % 7; // 0 = Sunday
  final weekday = dow != 0 && dow != 6;
  final seed = math.sin((day + month * 31) * 2.3).abs();
  final crewN = weekday ? 3 + (seed * 4).round() : (seed > 0.62 ? 2 : 0);
  final perTech = List<double>.generate(workers.length, (x) {
    if (x >= crewN) return 0;
    return (((6 + ((seed * 7 + x * 1.7) % 4)) * 10).round()) / 10;
  });
  final hours = (perTech.fold<double>(0, (a, b) => a + b) * 10).round() / 10;
  final ot =
      (perTech.where((v) => v > 8).fold<double>(0, (a, v) => a + (v - 8)) * 10).round() / 10;
  final status = crewN == 0
      ? ApprovalStatus.closed
      : day < 20
          ? ApprovalStatus.approved
          : day < 26
              ? ApprovalStatus.submitted
              : ApprovalStatus.draft;
  return DayMeta(day: day, crewN: crewN, perTech: perTech, hours: hours, ot: ot, status: status);
}

int daysInMonth(int month) => DateTime(kYear, month + 2, 0).day;

/// Monday-based offset of the 1st (0 = Monday).
int monthStartOffset(int month) {
  final first = DateTime(kYear, month + 1, 1).weekday % 7; // 0 Sun
  return (first + 6) % 7;
}

Color statusColor(ApprovalStatus s) => switch (s) {
      ApprovalStatus.approved => Wb.forest,
      ApprovalStatus.submitted => Wb.purple,
      ApprovalStatus.draft => Wb.gold,
      ApprovalStatus.closed => Wb.line,
    };

String statusLabel(ApprovalStatus s) => switch (s) {
      ApprovalStatus.approved => 'Approved',
      ApprovalStatus.submitted => 'Submitted',
      ApprovalStatus.draft => 'Draft',
      ApprovalStatus.closed => 'Closed',
    };
