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
    // `this._history` would satisfy the lint, but a private initialising
    // formal puts an underscore in the public API's parameter list, and
    // `history:` is what INTEGRATION.md documents.
    RxScheduleHistory? history,
    // ignore: prefer_initializing_formals
  })  : _history = history,
        technicians = List.unmodifiable(technicians ?? kDemoTechnicians),
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
  MonthMode monthMode = MonthMode.hours;
  bool approved = false;
  String? flash;
  final Map<int, ClockOverride> _clocks = {};
  final Set<String> _onClock = {};

  RxScheduleHistory? _history;

  /// Whether this board is drawing a host's real hours or the demo's planned
  /// ones. Surfaces that must not caption themselves as a timesheet read it.
  bool get hasHistory => _history != null;

  /// Supply — or replace — the host's worked history. See
  /// [RxScheduleHistory]; pass null to go back to planned shifts.
  ///
  /// Call it whenever the host's own data changes: the board is a view of
  /// whatever this returns, so a re-read of the punch log is one `setHistory`
  /// away from being on screen.
  void setHistory(RxScheduleHistory? history) {
    _history = history;
    notifyListeners();
  }

  /// The host's history for one technician on one day, or null. Surfaces that
  /// need the raw [ClockHours] — not the day's [DayMeta] — read it here rather
  /// than holding their own reference to the callback.
  ClockHours? historyFor(String technicianId, DateTime day) =>
      _history?.call(technicianId, day);

  /// The day's figures, from the history when there is one.
  DayMeta metaFor(DateTime when) {
    final h = _history;
    if (h != null) return dayMetaFrom(h, technicians, when);
    return dayMeta(when.month - 1, when.day,
        technicianCount: technicians.length);
  }

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
    // ⚠️ **History wins over the planned window**, and a null from it means
    // *did not work* rather than *fall back to the rota*. A planned shift
    // drawn on a day nobody punched is a bar that looks like evidence.
    final h = _history;
    if (h != null && _clocks[i] == null) {
      return h(technicians[i].id, date) ??
          const ClockHours(inHour: 0, outHour: 0, breakAt: 0);
    }
    final w = technicians[i];
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
  DayWindow get window =>
      DayWindow.of(List.generate(technicians.length, clockOf));

  /// **Settled and still-running, apart.**
  ///
  /// ⚠️ Adding them is what a four-column timesheet does, and it is how a
  /// forgotten Friday punch reaches payroll as an ordinary number that grew
  /// all weekend. Every surface that shows a total shows these two.
  ({double settled, double open}) get payableSplit {
    var settled = 0.0, running = 0.0;
    for (var i = 0; i < technicians.length; i++) {
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
  int get forgottenCount => List.generate(technicians.length, clockOf)
      .where((c) => c.forgotten)
      .length;

  int get liveCount =>
      List.generate(technicians.length, clockOf).where((c) => c.live).length;

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
      for (var i = 0; i < technicians.length; i++) {
        final c = clockOf(i);
        if (h >= c.inHour && h < c.outHour) busy++;
      }
      return busy;
    });
  }

  void nudge(int i, {required bool inSide, required double delta}) {
    // ⚠️ **A nudge cannot touch a real punch log.** It writes a
    // `ClockOverride`, which `clockOf` reads *instead of* the history — so
    // dragging a shift somebody actually worked discarded their punches and
    // redrew the row from this technician's planned window. Anna's real
    // 08:45–17:10 became 09:00–17:00, on screen, presented as an edit that
    // had worked. Nothing was written either way: `nudge` emits no
    // `ClockEvent`, so no host ever hears about it and a reload reverts it.
    //
    // Correcting a punch is a stated time, deliberately, through the host's
    // own write path. It is not a bar dragged half an hour.
    if (_history != null) return;
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
