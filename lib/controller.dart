import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'theme.dart';
import 'toast.dart';

class ClockOverride {
  const ClockOverride({required this.inHour, required this.outHour});
  final double inHour, outHour;
}

/// Host-facing scheduler state. Share one instance across RepairX routes so
/// POS / ticket clock-in updates the bench calendar (and the reverse).
class RxSchedulerController extends ChangeNotifier implements RxToastSource {
  RxSchedulerController({
    List<Technician>? technicians,
    DateTime Function()? now,
    DateTime? initialDate,
    this.workshopName = 'Northline Device Repair — Workshop 02',
    bool seedOnTheClock = true,
  })  : technicians = List.unmodifiable(technicians ?? kDemoTechnicians),
        now = now ?? _demoNow {
    final seed = initialDate ?? this.now();
    day = seed.day;
    month = seed.month - 1;
    if (seedOnTheClock) {
      final h = hourFromDateTime(this.now());
      for (final t in this.technicians) {
        if (h >= t.clockIn && h < t.clockOut) {
          _onClock.add(t.id);
        }
      }
    }
  }

  /// Demo "now" matches the mockup: 1:45p on Monday 24 August 2026.
  static DateTime _demoNow() => DateTime(kYear, 8, 24, 13, 45);

  final List<Technician> technicians;
  final DateTime Function() now;
  final String workshopName;

  int day = 24;
  int month = 7;
  TimelineView view = TimelineView.clock;
  int? sheetIndex;
  SheetTab sheetTab = SheetTab.clock;
  bool monthOpen = false;
  MonthMode monthMode = MonthMode.hours;
  bool approved = false;
  String? flash;
  final Map<int, ClockOverride> _clocks = {};
  final Set<String> _onClock = {};

  final _clockEvents = StreamController<ClockEvent>.broadcast(sync: true);
  final _toasts = StreamController<RxToastMessage>.broadcast(sync: true);

  @override
  Stream<RxToastMessage> get toasts => _toasts.stream;

  /// Clock in/out punches for other RepairX screens to listen to.
  Stream<ClockEvent> get clockEvents => _clockEvents.stream;

  DateTime get date => DateTime(kYear, month + 1, day);
  int get lastDay => daysInMonth(month);
  double get capacity => technicians.length * 8.5;
  double get nowHour => hourFromDateTime(now());

  int? indexOf(String technicianId) {
    final i = technicians.indexWhere((t) => t.id == technicianId);
    return i < 0 ? null : i;
  }

  Technician technicianAt(int i) => technicians[i];

  Technician? technicianById(String id) {
    final i = indexOf(id);
    return i == null ? null : technicians[i];
  }

  ClockHours clockOf(int i) {
    final w = technicians[i];
    final o = _clocks[i];
    return ClockHours(
      inHour: o?.inHour ?? w.clockIn,
      outHour: o?.outHour ?? w.clockOut,
      breakAt: w.breakAt,
    );
  }

  ClockHours? hoursFor(String technicianId) {
    final i = indexOf(technicianId);
    return i == null ? null : clockOf(i);
  }

  /// Live punch state. Independent of the shift bar on the calendar.
  bool isOnTheClock(String technicianId) => _onClock.contains(technicianId);

  /// Technician ids currently punched in.
  Set<String> get onTheClockIds => Set.unmodifiable(_onClock);

  List<RepairJob> jobsOf(int i) => repairJobsFor(i, day, clockOf(i).inHour);

  double get totalHours =>
      List.generate(technicians.length, clockOf).fold<double>(0, (a, c) => a + c.paid);

  double get overtimeHours => List.generate(technicians.length, clockOf).fold<double>(0, (a, c) {
        final extra = c.paid - 8;
        return extra > 0 ? a + extra : a;
      });

  double get billable {
    var sum = 0.0;
    for (var i = 0; i < technicians.length; i++) {
      for (final j in jobsOf(i)) {
        sum += j.duration * j.rate;
      }
    }
    return sum;
  }

  int get clockedCount =>
      List.generate(technicians.length, clockOf).where((c) => c.paid > 0).length;

  List<StatTile> get stats {
    final cap = capacity;
    final total = totalHours;
    final ot = overtimeHours;
    final util = (total / cap * 100).round();
    return [
      StatTile(
        label: 'Clocked hours',
        value: total.toStringAsFixed(1),
        unit: 'hours',
        sub: 'of ${cap.toStringAsFixed(0)}h capacity',
        dot: Wb.teal,
        bar: Wb.teal,
      ),
      StatTile(
        label: 'Utilisation',
        value: '$util%',
        unit: '',
        sub: '3 slots after 3pm',
        dot: Wb.forest,
        bar: Wb.forest,
      ),
      StatTile(
        label: 'Overtime',
        value: ot.toStringAsFixed(1),
        unit: 'hours',
        sub: ot > 0 ? '2 techs past 8h' : 'within limits',
        dot: Wb.accent,
        bar: Wb.accent,
        valueColor: ot > 0 ? Wb.accent : null,
      ),
      StatTile(
        label: 'Billable labour',
        value: '\$${(billable / 1000).toStringAsFixed(1)}k',
        unit: '',
        sub: 'parts excluded',
        dot: Wb.gold,
        bar: Wb.gold,
      ),
    ];
  }

  double statBarWidth(StatTile s) {
    if (s.label.startsWith('Overtime')) {
      return (overtimeHours / 8).clamp(0, 1);
    }
    if (s.label.startsWith('Billable')) return 0.72;
    return (totalHours / capacity).clamp(0, 1);
  }

  List<int> coverageBusy() {
    final n = (kDaySpan * 2).round();
    return List<int>.generate(n, (k) {
      final h = kDayStart + k / 2;
      var busy = 0;
      for (var i = 0; i < technicians.length; i++) {
        final c = clockOf(i);
        if (h >= c.inHour && h < c.outHour) busy++;
      }
      return busy;
    });
  }

  void nudge(int i, {required bool inSide, required double delta}) {
    final c = clockOf(i);
    var nextIn = c.inHour;
    var nextOut = c.outHour;
    if (inSide) {
      nextIn = (c.inHour + delta).clamp(kDayStart, kDayEnd);
    } else {
      nextOut = (c.outHour + delta).clamp(kDayStart, kDayEnd);
    }
    if (nextOut - nextIn < 0.5) return;
    _clocks[i] = ClockOverride(inHour: nextIn, outHour: nextOut);
    notifyListeners();
  }

  /// Clock this technician in at [at] (defaults to [now]). Safe to call from
  /// any RepairX screen that holds this controller.
  ClockResult clockIn(String technicianId, {DateTime? at, bool silent = false}) {
    final i = indexOf(technicianId);
    if (i == null) {
      return _fail('Unknown technician', silent: silent);
    }
    final tech = technicians[i];
    if (isOnTheClock(technicianId)) {
      return _fail('${_shortName(tech.name)} is already on the clock', silent: silent);
    }
    final punch = at ?? now();
    final h = hourFromDateTime(punch).clamp(kDayStart, kDayEnd - 0.5);
    final existing = clockOf(i);
    var out = existing.outHour;
    if (out <= h) out = (h + 8).clamp(h + 0.5, kDayEnd);
    _clocks[i] = ClockOverride(inHour: h, outHour: out);
    _onClock.add(technicianId);
    final hours = clockOf(i);
    final event = ClockEvent(
      technicianId: technicianId,
      technicianName: tech.name,
      action: ClockAction.clockIn,
      at: punch,
      hours: hours,
    );
    return _ok(
      event,
      title: '${_shortName(tech.name)} clocked in',
      detail: formatHour(h),
      kind: RxToastKind.success,
      silent: silent,
    );
  }

  /// Clock this technician out at [at] (defaults to [now]).
  ClockResult clockOut(String technicianId, {DateTime? at, bool silent = false}) {
    final i = indexOf(technicianId);
    if (i == null) {
      return _fail('Unknown technician', silent: silent);
    }
    final tech = technicians[i];
    if (!isOnTheClock(technicianId)) {
      return _fail('${_shortName(tech.name)} is not on the clock', silent: silent, kind: RxToastKind.warning);
    }
    final punch = at ?? now();
    final h = hourFromDateTime(punch).clamp(kDayStart + 0.5, kDayEnd);
    final existing = clockOf(i);
    var out = h;
    if (out - existing.inHour < 0.5) out = existing.inHour + 0.5;
    _clocks[i] = ClockOverride(inHour: existing.inHour, outHour: out);
    _onClock.remove(technicianId);
    final hours = clockOf(i);
    final event = ClockEvent(
      technicianId: technicianId,
      technicianName: tech.name,
      action: ClockAction.clockOut,
      at: punch,
      hours: hours,
    );
    final ot = hours.overtime ? ' · ${hours.paid.toStringAsFixed(1)}h overtime' : '';
    return _ok(
      event,
      title: '${_shortName(tech.name)} clocked out',
      detail: '${formatHour(existing.inHour)}–${formatHour(out)} · ${hours.paid.toStringAsFixed(1)}h$ot',
      kind: hours.overtime ? RxToastKind.warning : RxToastKind.info,
      silent: silent,
    );
  }

  ClockResult _fail(
    String message, {
    required bool silent,
    RxToastKind kind = RxToastKind.danger,
  }) {
    if (!silent) _emitToast(RxToastMessage(title: message, kind: kind));
    return ClockResult(ok: false, message: message);
  }

  ClockResult _ok(
    ClockEvent event, {
    required String title,
    String? detail,
    required RxToastKind kind,
    required bool silent,
  }) {
    _clockEvents.add(event);
    if (!silent) {
      _emitToast(RxToastMessage(title: title, detail: detail, kind: kind));
    }
    notifyListeners();
    return ClockResult(ok: true, message: title, event: event);
  }

  void _emitToast(RxToastMessage message) {
    flash = message.title;
    _toasts.add(message);
  }

  String _shortName(String name) => name.split(' (').first;

  void prevDay() {
    if (day <= 1) return;
    day -= 1;
    sheetIndex = null;
    notifyListeners();
  }

  void nextDay() {
    if (day >= lastDay) return;
    day += 1;
    sheetIndex = null;
    notifyListeners();
  }

  void today() {
    final n = now();
    day = n.day;
    month = n.month - 1;
    sheetIndex = null;
    notifyListeners();
  }

  void setView(TimelineView v) {
    view = v;
    notifyListeners();
  }

  void openSheet(int i, {SheetTab tab = SheetTab.clock}) {
    sheetIndex = i;
    sheetTab = tab;
    notifyListeners();
  }

  void closeSheet() {
    sheetIndex = null;
    notifyListeners();
  }

  void setSheetTab(SheetTab t) {
    sheetTab = t;
    notifyListeners();
  }

  void openMonth() {
    monthOpen = true;
    notifyListeners();
  }

  void closeMonth() {
    monthOpen = false;
    notifyListeners();
  }

  void setMonthMode(MonthMode m) {
    monthMode = m;
    notifyListeners();
  }

  void prevMonth() {
    if (month <= 0) return;
    month -= 1;
    if (day > lastDay) day = lastDay;
    notifyListeners();
  }

  void nextMonth() {
    if (month >= 11) return;
    month += 1;
    if (day > lastDay) day = lastDay;
    notifyListeners();
  }

  void pickDay(int d) {
    day = d;
    monthOpen = false;
    sheetIndex = null;
    notifyListeners();
  }

  void copyWeek() {
    sheetIndex = null;
    _emitToast(
      const RxToastMessage(
        title: 'Copied last week onto this bench',
        kind: RxToastKind.info,
      ),
    );
    notifyListeners();
  }

  void approve() {
    approved = true;
    _emitToast(
      const RxToastMessage(
        title: '4 timesheets approved',
        kind: RxToastKind.success,
      ),
    );
    notifyListeners();
  }

  void clearFlash() => flash = null;

  /// Push a toast through the same overlay [RxToastHost] listens to.
  void showToast(
    String title, {
    String? detail,
    RxToastKind kind = RxToastKind.info,
  }) {
    _emitToast(RxToastMessage(title: title, detail: detail, kind: kind));
  }

  List<double> weekLoad(int i) {
    final paid = clockOf(i).paid;
    return [6.5, 8, 8.5, 9.5, paid, 7, 0];
  }

  @override
  void dispose() {
    _clockEvents.close();
    _toasts.close();
    super.dispose();
  }
}

/// @nodoc
typedef SchedulerController = RxSchedulerController;
