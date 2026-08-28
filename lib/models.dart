import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The fallback day, used when nothing has been punched at all.
///
/// ⚠️ **A window is derived from the punches wherever there are any** — see
/// `DayWindow.of`. A hardcoded 07:30 drops the 06:30 opener: the shift exists,
/// the board simply cannot draw it, which is the worst way for a scheduler to
/// be wrong.
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

/// A bench technician. [id] is the stable key other apps use for clock in/out.
class Technician {
  const Technician({
    required this.id,
    required this.name,
    required this.role,
    required this.initial,
    required this.cert,
    required this.tint,
    this.clockIn = 9,
    this.clockOut = 17,
    this.breakAt = 0,
  });

  final String id;
  final String name, role, initial, cert;
  final Color tint;
  final double clockIn, clockOut, breakAt;
}

/// @nodoc
typedef Worker = Technician;

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
  const ClockHours({
    required this.inHour,
    required this.outHour,
    required this.breakAt,
    this.breakHours = 0.5,
    this.open = false,
  });

  final double inHour, outHour, breakAt;

  /// How long the break actually was.
  ///
  /// ⚠️ **It used to be hardcoded** — every bar's subline read `· 30m break`
  /// whatever the punches said, so a 45-minute lunch printed as half an hour
  /// on the one screen that exists to report hours. A default is kept because
  /// the seeded rota has no real figure to give, but a host supplying a
  /// history supplies this too.
  final double breakHours;

  /// The run began before this day's midnight — a shift somebody started
  /// yesterday and never closed. Drawn clipped to the left edge.
  bool get entersDay => inHour < 0;

  /// **Nobody clocked out of this one.** [outHour] is then a *cap* — where the
  /// clock had got to when it was read — not a punch somebody made.
  ///
  /// It earns its own flag because an open run and a settled one are drawn as
  /// different things, not as two shades of one: time that is on the clock is
  /// solid, time nobody has confirmed is dotted. `RxTrackBar`'s rule in
  /// RepairX, and the reason this app can show the state at all.
  final bool open;

  double get paid => outHour - inHour;
  bool get overtime => paid > 8;
  bool get hasBreak => breakAt > 0;

  /// The break as a fraction of the drawn run, for a mark painted over it.
  /// Clamped into the bar: a break recorded outside the run it belongs to is
  /// a punch to fix, not a reason to paint outside the shift.
  (double, double) get breakBand {
    final span = outHour - inHour;
    if (span <= 0 || !hasBreak) return (0, 0);
    final at = ((breakAt - inHour) / span).clamp(0.0, 1.0);
    return (at, (breakHours / span).clamp(0.0, 1.0 - at));
  }

  /// Somebody is on shift *right now*: open, and the clock has not run past
  /// what a shift plausibly is.
  ///
  /// ⚠️ **From the punch stream alone, running and forgotten are the same
  /// event.** Only elapsed time separates them, which is why this is the one
  /// place that line is drawn — and why it is generous. A double shift, an
  /// overnight recovery and a stocktake past closing are all real; calling one
  /// an error trains people to ignore the flag.
  bool get live => open && paid < kImplausibleShift;

  /// Open long enough that nobody is standing in it.
  bool get forgotten => open && !live;
}

/// Sixteen hours, not eight. See [ClockHours.live].
const double kImplausibleShift = 16;

/// Snap a hairline to the pixel grid.
///
/// ⚠️ Skia spreads a 1px line drawn at a fractional x across two columns at
/// about half strength each — every rule on the board drawn at half its weight
/// and twice its width, which reads as blur rather than as a fainter line.
/// Bars are deliberately **not** snapped: a bar's edges are the data, and
/// rounding 07:12 to the nearest pixel is rounding the punch.
double crispLine(double x) => x.floorToDouble() + 0.5;

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

/// Demo crew used when the host does not pass technicians.
const kDemoTechnicians = <Technician>[
  Technician(
    id: 'ak',
    name: 'Alex Kim (you)',
    role: 'Lead Tech',
    initial: 'AK',
    cert: 'Board L3',
    tint: Wb.primary,
    clockIn: 13,
    clockOut: 19,
    breakAt: 16,
  ),
  Technician(
    id: 'pr',
    name: 'Priya Raman',
    role: 'Micro-solder',
    initial: 'PR',
    cert: 'IPC-7711',
    tint: Wb.forest,
    clockIn: 8,
    clockOut: 16.5,
    breakAt: 12,
  ),
  Technician(
    id: 'rm',
    name: 'Rufus Mbeki',
    role: 'Screen Bench',
    initial: 'RM',
    cert: 'OEM Cert',
    tint: Wb.info,
    clockIn: 10,
    clockOut: 17,
    breakAt: 13,
  ),
  Technician(
    id: 'tl',
    name: 'Tobias Lund',
    role: 'Diagnostics',
    initial: 'TL',
    cert: 'Level 2',
    tint: Wb.toneWarningFg,
    clockIn: 12,
    clockOut: 17,
    breakAt: 14.5,
  ),
  Technician(
    id: 'bh',
    name: 'Benjamin Hale',
    role: 'Apprentice',
    initial: 'BH',
    cert: 'Year 2',
    tint: Wb.gold,
    clockIn: 10,
    clockOut: 13,
    breakAt: 0,
  ),
  Technician(
    id: 'nc',
    name: 'Nina Castel',
    role: 'QC / Intake',
    initial: 'NC',
    cert: 'QA Lead',
    tint: Wb.muted3,
    clockIn: 9,
    clockOut: 14,
    breakAt: 11.5,
  ),
  Technician(
    id: 'tb',
    name: 'Tom Braddock',
    role: 'Data Recovery',
    initial: 'TB',
    cert: 'Chip-off',
    tint: Wb.toneInfoFg,
    clockIn: 11,
    clockOut: 19,
    breakAt: 15,
  ),
];

/// @nodoc
const workers = kDemoTechnicians;

/// Hour of day as a fractional 24h value (`13.75` = 1:45p).
double hourFromDateTime(DateTime t) =>
    t.hour + t.minute / 60.0 + t.second / 3600.0 + t.millisecond / 3600000.0;

enum ClockAction { clockIn, clockOut }

class ClockEvent {
  const ClockEvent({
    required this.technicianId,
    required this.technicianName,
    required this.action,
    required this.at,
    required this.hours,
  });

  final String technicianId;
  final String technicianName;
  final ClockAction action;
  final DateTime at;
  final ClockHours hours;

  bool get overtime => hours.overtime;
}

class ClockResult {
  const ClockResult({
    required this.ok,
    required this.message,
    this.event,
  });

  final bool ok;
  final String message;
  final ClockEvent? event;
}

const jobSeeds = <List<JobSeed>>[
  [
    JobSeed(
      title: 'iPhone 14 Pro · glass',
      kind: JobKind.screen,
      start: 8,
      duration: 2.5,
      rate: 95,
    ),
    JobSeed(
      title: 'Pixel 8 · board rework',
      kind: JobKind.board,
      start: 11,
      duration: 3.5,
      rate: 140,
    ),
    JobSeed(
      title: 'Intake triage',
      kind: JobKind.diag,
      start: 15,
      duration: 1.5,
      rate: 70,
    ),
  ],
  [
    JobSeed(
      title: 'MacBook A2338 · CPU line',
      kind: JobKind.board,
      start: 8.5,
      duration: 4,
      rate: 150,
    ),
    JobSeed(
      title: 'S23 · charge port',
      kind: JobKind.board,
      start: 13,
      duration: 2.5,
      rate: 120,
    ),
  ],
  [
    JobSeed(
      title: 'iPad 9 · digitizer ×3',
      kind: JobKind.screen,
      start: 8,
      duration: 4.5,
      rate: 88,
    ),
    JobSeed(
      title: 'iPhone 12 · LCD swap',
      kind: JobKind.screen,
      start: 13.5,
      duration: 2,
      rate: 88,
    ),
  ],
  [
    JobSeed(
      title: 'Warranty diagnostics',
      kind: JobKind.diag,
      start: 9,
      duration: 3,
      rate: 70,
    ),
    JobSeed(
      title: 'S22 Ultra · liquid',
      kind: JobKind.water,
      start: 12.5,
      duration: 3.5,
      rate: 110,
    ),
  ],
  [
    JobSeed(
      title: 'Battery bench · 6 units',
      kind: JobKind.battery,
      start: 8,
      duration: 3.5,
      rate: 60,
    ),
    JobSeed(
      title: 'Pixel 7a · battery',
      kind: JobKind.battery,
      start: 12,
      duration: 1.5,
      rate: 60,
    ),
  ],
  [
    JobSeed(
      title: 'QC pass · outbound',
      kind: JobKind.diag,
      start: 8.5,
      duration: 2,
      rate: 75,
    ),
    JobSeed(
      title: 'iPhone 13 · water rescue',
      kind: JobKind.water,
      start: 11,
      duration: 4.5,
      rate: 110,
    ),
  ],
  [
    JobSeed(
      title: 'Chip-off recovery',
      kind: JobKind.board,
      start: 9.5,
      duration: 5,
      rate: 165,
    ),
    JobSeed(
      title: 'Client handover',
      kind: JobKind.diag,
      start: 15,
      duration: 1,
      rate: 75,
    ),
  ],
];

/// ISO-8601 week number. Thursday decides the year, which is the whole rule:
/// a week is in the year holding most of its days.
int isoWeekOf(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  final thursday = day.add(Duration(days: 4 - (day.weekday == 7 ? 7 : day.weekday)));
  final jan1 = DateTime(thursday.year, 1, 1);
  return 1 + (thursday.difference(jan1).inDays / 7).floor();
}

/// 24-hour clock label (`08:45`, `17:10`).
///
/// What a host drawing a real punch log wants: `8.4h` and `5:10p` are a
/// rounding and a reading of somebody's pay, and a shop reconciling a
/// timesheet reads the punch back as it was made.
String formatClock(double h) {
  final hh = h.floor();
  final mm = ((h - hh) * 60).round();
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

/// A span of hours as `HH:MM` — `7.666` is `07:40`, not `7.7h`.
String formatSpan(double hours) {
  final h = hours.abs().floor();
  final m = ((hours.abs() - h) * 60).round();
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

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
    out.add(
      RepairJob(
        title: b.title,
        kind: b.kind,
        start: t,
        duration: dur,
        rate: b.rate,
      ),
    );
    t += dur + 0.5;
  }
  return out;
}

/// **What a technician actually worked on a given day**, supplied by the host.
///
/// This is the capability that turns the bench from a planner into a board
/// that can draw a shop's real history. Without it the calendar renders each
/// technician's *planned* window plus punches made while it is mounted —
/// which is a rota, not a timesheet, and captioning one as the other is the
/// wrong-but-plausible claim this package refuses to make on a host's behalf.
///
/// Return `null` for "that person did not work that day"; the board then draws
/// their lane empty rather than falling back to a planned shift, because an
/// empty lane is a fact and a planned one nobody worked is a fiction.
///
/// ⚠️ It must be **cheap and synchronous** — the board calls it per technician
/// per painted day, and the month grid calls it across a whole month. Hosts
/// should answer from something already in memory (RepairX hands it a map
/// built from one `time_entries` read), never from a network call.
typedef RxScheduleHistory = ClockHours? Function(
  String technicianId,
  DateTime day,
);

/// [dayMeta] over a real history rather than the demo's generator.
///
/// The same shape, so every surface that reads a [DayMeta] — the month cells,
/// the week column, the totals — works unchanged whichever source is behind
/// it. That is the whole point of adding the capability here rather than a
/// second month grid in the host.
DayMeta dayMetaFrom(
  RxScheduleHistory history,
  List<Technician> technicians,
  DateTime when,
) {
  final perTech = <double>[
    for (final t in technicians) history(t.id, when)?.paid ?? 0,
  ];
  final crewN = perTech.where((v) => v > 0).length;
  final hours = (perTech.fold<double>(0, (a, b) => a + b) * 10).round() / 10;
  final ot =
      (perTech.where((v) => v > 8).fold<double>(0, (a, v) => a + (v - 8)) * 10)
              .round() /
          10;
  return DayMeta(
    day: when.day,
    crewN: crewN,
    perTech: perTech,
    hours: hours,
    // ⚠️ **No approval state is invented.** A host with real hours has no
    // sign-off model here, and a day drawn "approved" because it had hours in
    // it would be the board asserting somebody signed something.
    ot: ot,
    status: crewN == 0 ? ApprovalStatus.closed : ApprovalStatus.draft,
  );
}

DayMeta dayMeta(int month, int day, {int technicianCount = 7}) {
  final dow = DateTime(kYear, month + 1, day).weekday % 7; // 0 = Sunday
  final weekday = dow != 0 && dow != 6;
  final seed = math.sin((day + month * 31) * 2.3).abs();
  final crewN = weekday ? 3 + (seed * 4).round() : (seed > 0.62 ? 2 : 0);
  final perTech = List<double>.generate(technicianCount, (x) {
    if (x >= crewN) return 0;
    return (((6 + ((seed * 7 + x * 1.7) % 4)) * 10).round()) / 10;
  });
  final hours = (perTech.fold<double>(0, (a, b) => a + b) * 10).round() / 10;
  final ot =
      (perTech.where((v) => v > 8).fold<double>(0, (a, v) => a + (v - 8)) * 10)
          .round() /
      10;
  final status = crewN == 0
      ? ApprovalStatus.closed
      : day < 20
      ? ApprovalStatus.approved
      : day < 26
      ? ApprovalStatus.submitted
      : ApprovalStatus.draft;
  return DayMeta(
    day: day,
    crewN: crewN,
    perTech: perTech,
    hours: hours,
    ot: ot,
    status: status,
  );
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

/// The hours a board draws, derived from what is actually on it.
class DayWindow {
  const DayWindow(this.start, this.end);

  /// From the day's own clocks, whole hours, never narrower than [minSpan]
  /// so a single short shift does not fill the width.
  ///
  /// ⚠️ **Only a punch may widen it.** An open run's *cap* is not evidence:
  /// a shift nobody closed runs to now, so counted as a punch one forgotten
  /// clock-out puts the whole board on a 24-hour axis and squashes every real
  /// shift to a third of its width — the one thing the board exists to show
  /// making everything else unreadable.
  factory DayWindow.of(Iterable<ClockHours> clocks, {double minSpan = 8}) {
    var lo = 24.0, hi = 0.0;
    for (final c in clocks) {
      if (c.paid <= 0) continue;
      // ⚠️ **A run that entered from yesterday does not widen the day.** Its
      // clock-in is before this midnight (a negative hour), and taking it as
      // the day's start pulls the axis back into the small hours and squashes
      // every real shift — the same failure an open run's *end* causes, one
      // edge over.
      if (c.inHour >= 0 && c.inHour < lo) lo = c.inHour;
      if (!c.open && c.outHour > hi) hi = c.outHour;
    }
    if (lo > hi) return const DayWindow(kDayStart, kDayEnd);
    lo = lo.floorToDouble();
    hi = hi.ceilToDouble();
    while (hi - lo < minSpan) {
      if (hi < 24) hi += 1;
      if (hi - lo >= minSpan) break;
      if (lo > 0) lo -= 1;
    }
    return DayWindow(lo, hi);
  }

  final double start, end;
  double get span => end - start;
  double pctOf(double hour) => span <= 0 ? 0 : (hour - start) / span;
}

/// The same day, seen as **one technician's**.
///
/// ⚠️ This is what makes the self view reuse the admin month *unchanged*
/// rather than fork it. A cell's cluster is one bar per technician; project
/// the month down to a single slot and the identical grid draws one person's
/// month, with every figure — hours, the week column, the totals — following
/// automatically. Owner, 2026-08-27: *"utilize the same admin month view."*
DayMeta onlyTech(DayMeta m, int index) {
  final mine = index < m.perTech.length ? m.perTech[index] : 0.0;
  return DayMeta(
    day: m.day,
    crewN: mine > 0 ? 1 : 0,
    perTech: [
      for (var i = 0; i < m.perTech.length; i++) i == index ? mine : 0.0,
    ],
    hours: mine,
    // Overtime is per person, so it cannot be carried over from the bench's
    // total — it is recomputed against the same eight-hour line.
    ot: mine > 8 ? mine - 8 : 0,
    status: m.status,
  );
}

/// One technician's clock on one day of the month, derived from the same
/// [dayMeta] the month grid reads.
///
/// One source for both, deliberately: a self view whose week disagreed with
/// its own month by an hour would be two answers to one question.
ClockHours? clockForDayOf(int index, int month, int day) {
  final meta = dayMeta(month, day);
  final hours = index < meta.perTech.length ? meta.perTech[index] : 0.0;
  if (hours <= 0) return null;
  // ⚠️ **The start has to move.** Keyed off the worker's own habit but
  // nudged by the date, because a week where every bar begins at the same
  // hour is a bar chart with dates down the side — the one thing a *schedule*
  // is supposed to show is that Tuesday started late.
  final w = workers[index];
  final drift = ((day * 7 + index * 3) % 5) * 0.5;
  final start = (w.clockIn.clamp(7.0, 10.0) + drift - 1).clamp(6.0, 11.0);
  return ClockHours(
    inHour: start,
    outHour: start + hours,
    breakAt: hours > 5 ? start + hours / 2 : 0,
  );
}
