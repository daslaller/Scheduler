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
  MonthMode monthMode = MonthMode.hours;
  bool approved = false;
  String? flash;
  final Map<int, ClockOverride> _clocks = {};

  DateTime get date => DateTime(kYear, month + 1, day);
  int get lastDay => daysInMonth(month);
  double get capacity => workers.length * 8.5;

  /// Who has not clocked out, and when they clocked **in**.
  ///
  /// Index 4 clocked in this morning and is on shift now. Index 3 clocked in
  /// yesterday evening — a negative hour, i.e. before this day's midnight —
  /// and nobody ever closed it.
  ///
  /// ⚠️ **Both are `open`; only elapsed time separates them**, which is the
  /// whole point. A fixture where every shift is settled cannot show the
  /// distinction the board is built to draw, and a fixture where the
  /// "forgotten" one started this morning is not forgotten at all — it is
  /// somebody at the counter.
  static const _openIn = {3: kNowHour - 20, 4: 10.0};

  ClockHours clockOf(int i) {
    final w = workers[i];
    final o = _clocks[i];
    // A nudged clock is a clock somebody has stated, so it closes.
    final open = o == null && _openIn.containsKey(i);
    return ClockHours(
      inHour: open ? _openIn[i]! : (o?.inHour ?? w.clockIn),
      // ⚠️ An open shift's end is a **cap at now**, not a punch: what the
      // clock had reached when the board was read.
      outHour: open ? kNowHour : (o?.outHour ?? w.clockOut),
      breakAt: open ? 0 : w.breakAt,
      open: open,
    );
  }

  /// The day's window, derived — see [DayWindow].
  DayWindow get window => DayWindow.of(List.generate(workers.length, clockOf));

  /// **Settled and still-running, apart.**
  ///
  /// ⚠️ Adding them is what a four-column timesheet does, and it is how a
  /// forgotten Friday punch reaches payroll as an ordinary number that grew
  /// all weekend. Every surface that shows a total shows these two.
  ({double settled, double open}) get payableSplit {
    var settled = 0.0, running = 0.0;
    for (var i = 0; i < workers.length; i++) {
      final c = clockOf(i);
      if (c.open) {
        running += c.paid;
      } else {
        settled += c.paid;
      }
    }
    return (settled: settled, open: running);
  }

  /// Shifts nobody clocked out of **and nobody is standing in**.
  ///
  /// A shift you are standing in is not a fix: counting today's live clock-in
  /// as a problem is how the alarm stops being read by lunchtime on the first
  /// day.
  int get forgottenCount =>
      List.generate(workers.length, clockOf).where((c) => c.forgotten).length;

  int get liveCount =>
      List.generate(workers.length, clockOf).where((c) => c.live).length;

  List<RepairJob> jobsOf(int i) => repairJobsFor(i, day, clockOf(i).inHour);

  double get totalHours => List.generate(
    workers.length,
    clockOf,
  ).fold<double>(0, (a, c) => a + c.paid);

  double get overtimeHours =>
      List.generate(workers.length, clockOf).fold<double>(0, (a, c) {
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
    final util = (total / cap * 100).round();
    final split = payableSplit;
    final forgotten = forgottenCount;
    final live = liveCount;
    return [
      // ⚠️ **Settled, with the running hours named beside it — never added
      // in.** A single "clocked hours" figure is what a four-column timesheet
      // prints, and it is how a forgotten punch reaches payroll as an
      // ordinary number that grew all weekend.
      StatTile(
        label: 'On the bench',
        value: split.settled.toStringAsFixed(1),
        unit: 'hours',
        sub: split.open == 0
            ? 'all of it clocked out of'
            : '+${split.open.toStringAsFixed(1)}h still running',
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
      // ⚠️ **A shift somebody is standing in is not a fix.** Counting every
      // open clock puts today's live one in the alarm tile, which is how the
      // tile stops being read by lunchtime on the first day.
      StatTile(
        label: 'Unconfirmed',
        value: '$forgotten',
        unit: forgotten == 1 ? 'shift' : 'shifts',
        sub: forgotten > 0
            ? 'no clock-out — the hours are a guess'
            : live > 0
            ? 'nothing forgotten · $live still running'
            : 'every shift clocked out of',
        dot: Wb.accent,
        bar: Wb.accent,
        valueColor: forgotten > 0 ? Wb.accent : null,
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
    final w = window;
    final n = (w.span * 2).round();
    return List<int>.generate(n, (k) {
      final h = w.start + k / 2;
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
    sheetIndex = null;
    notifyListeners();
  }

  /// Which page is on screen. The self view is the same data seen as one
  /// person's, so it is a mode of this controller rather than its own.
  bool selfView = false;

  void showSelf(bool v) {
    selfView = v;
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
