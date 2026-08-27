import 'package:flutter/foundation.dart';

import 'models.dart';
import 'theme.dart';

class ClockOverride {
  const ClockOverride({required this.inHour, required this.outHour});
  final double inHour, outHour;
}

class SchedulerController extends ChangeNotifier {
  SchedulerController();

  int day = 24;
  int month = 7; // August
  TimelineView view = TimelineView.clock;
  int? sheetIndex;
  SheetTab sheetTab = SheetTab.clock;
  bool monthOpen = false;
  MonthMode monthMode = MonthMode.hours;
  bool approved = false;
  String? flash;
  final Map<int, ClockOverride> _clocks = {};

  DateTime get date => DateTime(kYear, month + 1, day);
  int get lastDay => daysInMonth(month);
  double get capacity => workers.length * 8.5;

  ClockHours clockOf(int i) {
    final w = workers[i];
    final o = _clocks[i];
    return ClockHours(
      inHour: o?.inHour ?? w.clockIn,
      outHour: o?.outHour ?? w.clockOut,
      breakAt: w.breakAt,
    );
  }

  List<RepairJob> jobsOf(int i) => repairJobsFor(i, day, clockOf(i).inHour);

  double get totalHours =>
      List.generate(workers.length, clockOf).fold<double>(0, (a, c) => a + c.paid);

  double get overtimeHours => List.generate(workers.length, clockOf).fold<double>(0, (a, c) {
        final extra = c.paid - 8;
        return extra > 0 ? a + extra : a;
      });

  double get billable {
    var sum = 0.0;
    for (var i = 0; i < workers.length; i++) {
      for (final j in jobsOf(i)) {
        sum += j.duration * j.rate;
      }
    }
    return sum;
  }

  int get clockedCount =>
      List.generate(workers.length, clockOf).where((c) => c.paid > 0).length;

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
      for (var i = 0; i < workers.length; i++) {
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
    day = 24;
    month = 7;
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
    flash = 'Copied last week onto this bench';
    notifyListeners();
  }

  void approve() {
    approved = true;
    flash = '4 timesheets approved';
    notifyListeners();
  }

  void clearFlash() => flash = null;

  List<double> weekLoad(int i) {
    final paid = clockOf(i).paid;
    return [6.5, 8, 8.5, 9.5, paid, 7, 0];
  }
}
