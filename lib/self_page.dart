/// **The technician's own view** — one person, a row per day.
///
/// Owner, 2026-08-27: *"The users self view, and utilize the same admin month
/// view."* So this is not a second scheduler: it is the bench lane with a
/// **date** in the lead cell instead of a person, and its Month button opens
/// the admin overlay projected onto one technician (`onlyTech`).
///
/// Four rules in it are about the reader's own pay, and each is the opposite
/// of what a roster board would do:
///
/// * **Every day in the period holds a lane, worked or not.** A week that
///   shrinks to the days somebody punched cannot show a day off — and cannot
///   show the Tuesday they meant to work.
/// * **A future day is drawn back.** It has not happened; at full weight it
///   reads as a day they failed to turn up for.
/// * **The now line is over ONE lane, not the whole column.** On the roster
///   every row is the same day, so a line down all of them is one time. Here
///   each row is a different day, and a full-height line would claim 09:41 on
///   Monday is the same moment as 09:41 on Thursday.
/// * **Settled and still-running stay apart**, as everywhere else.
library;

import 'package:flutter/material.dart';

import 'controller.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets/chrome.dart';
import 'widgets/month_overlay.dart';

const double _dateWidth = 150;
const double _rowH = 52;

class SelfPage extends StatelessWidget {
  const SelfPage({super.key, required this.ctrl, required this.index});

  final SchedulerController ctrl;

  /// Whose week. In RepairX this is the signed-in member; here it is the
  /// worker the app calls "you".
  final int index;

  @override
  Widget build(BuildContext context) {
    final w = workers[index];
    // The week the bench day sits in, Monday first.
    final anchor = ctrl.date;
    final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    final clocks = <DateTime, ClockHours?>{
      for (final d in days)
        d: d.month == ctrl.month + 1
            ? clockForDayOf(index, ctrl.month, d.day)
            : null,
    };
    // ⚠️ Derived from real punches only — an open run's cap may not widen it.
    final window = DayWindow.of(clocks.values.whereType<ClockHours>());

    var settled = 0.0;
    var running = 0.0;
    var worked = 0;
    var longest = 0.0;
    for (final c in clocks.values) {
      if (c == null) continue;
      worked++;
      if (c.paid > longest) longest = c.paid;
      if (c.open) {
        running += c.paid;
      } else {
        settled += c.paid;
      }
    }

    return ColoredBox(
      color: Wb.page,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              worker: w,
              monday: monday,
              onMonth: () =>
                  showMonthOverlay(context, ctrl: ctrl, onlyWorker: index),
            ),
            const SizedBox(height: 16),
            _Strip(
              settled: settled,
              running: running,
              worked: worked,
              days: days.length,
              longest: longest,
            ),
            const SizedBox(height: 16),
            _Board(
              days: days,
              clocks: clocks,
              window: window,
              today: ctrl.date,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.worker,
    required this.monday,
    required this.onMonth,
  });

  final Worker worker;
  final DateTime monday;
  final VoidCallback onMonth;

  @override
  Widget build(BuildContext context) {
    final sunday = monday.add(const Duration(days: 6));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MY SCHEDULE', style: Wb.kicker(size: 10.5, tracking: 0.16)),
            const SizedBox(height: 3),
            Text(
              '${monday.day} – ${sunday.day} ${kMonNames[sunday.month - 1]}',
              style: Wb.display(34),
            ),
          ],
        ),
        const Spacer(),
        // The page says whose week it is. Every row here is a *day*, so the
        // name is not in a column — and without this it states hours and
        // never states whose.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WbPill(label: 'Month', onTap: onMonth),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    worker.name,
                    style: Wb.ui(size: 13, weight: FontWeight.w600),
                  ),
                  Text(
                    worker.role,
                    style: Wb.kicker(size: 9.5, tracking: 0.09),
                  ),
                ],
              ),
              const SizedBox(width: 9),
              WbAvatar(initial: worker.initial, tint: worker.tint),
            ],
          ),
        ),
      ],
    );
  }
}

/// ⚠️ **Two numbers, never one.** This is the reader's own pay: a merged
/// total is precisely what a four-column timesheet prints.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.settled,
    required this.running,
    required this.worked,
    required this.days,
    required this.longest,
  });

  final double settled, running, longest;
  final int worked, days;

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, String value, String unit, String sub})>[
      (
        label: 'On the bench',
        value: settled.toStringAsFixed(1),
        unit: 'hours',
        sub: running == 0
            ? 'all of it clocked out of'
            : '+${running.toStringAsFixed(1)}h still running',
      ),
      (
        label: 'Days worked',
        value: '$worked',
        unit: 'of $days',
        sub: 'days you punched in on',
      ),
      // ⚠️ The label and the figure have to be the same claim. This tile
      // briefly said "Longest day" over an *average*, which is the kind of
      // quiet wrongness a reader only catches after acting on it.
      (
        label: 'Longest day',
        value: longest == 0 ? '—' : longest.toStringAsFixed(1),
        unit: 'hours',
        sub: 'the most you did in one go',
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Wb.cream,
        borderRadius: BorderRadius.circular(Wb.rXl),
        border: Border.all(color: Wb.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, t) in tiles.indexed)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : const Border(left: BorderSide(color: Wb.line)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.label.toUpperCase(),
                          style: Wb.kicker(size: 10, tracking: 0.15),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(t.value, style: Wb.display(30)),
                            const SizedBox(width: 6),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                t.unit,
                                style: Wb.ui(size: 12, color: Wb.muted2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(t.sub, style: Wb.ui(size: 11, color: Wb.muted2)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.days,
    required this.clocks,
    required this.window,
    required this.today,
  });

  final List<DateTime> days;
  final Map<DateTime, ClockHours?> clocks;
  final DayWindow window;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Wb.cream,
        borderRadius: BorderRadius.circular(Wb.rXl),
        border: Border.all(color: Wb.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Wb.rXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Ruler(window: window),
            for (final (i, d) in days.indexed)
              _Lane(
                day: d,
                clock: clocks[d],
                window: window,
                isToday: d.day == today.day && d.month == today.month,
                // A day that has not happened yet is drawn back.
                ahead: d.isAfter(today),
                first: i == 0,
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.window});
  final DayWindow window;

  @override
  Widget build(BuildContext context) {
    final hours = <int>[];
    for (var h = window.start.ceil(); h < window.end.floor(); h++) {
      hours.add(h);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Wb.pad, 12, Wb.pad, 0),
      child: Row(
        children: [
          const SizedBox(width: _dateWidth),
          Expanded(
            child: SizedBox(
              height: 20,
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    for (var k = 0; k < hours.length; k++)
                      Positioned(
                        left: window.pctOf(hours[k].toDouble()) * box.maxWidth,
                        top: 0,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            border: Border(left: BorderSide(color: Wb.line2)),
                          ),
                          child: k.isEven
                              ? Text(
                                  formatHour(hours[k].toDouble()),
                                  style: Wb.code(
                                    size: 10,
                                    weight: FontWeight.w500,
                                    color: Wb.muted,
                                    tracking: 0.06,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.day,
    required this.clock,
    required this.window,
    required this.isToday,
    required this.ahead,
    required this.first,
  });

  final DateTime day;
  final ClockHours? clock;
  final DayWindow window;
  final bool isToday, ahead, first;

  @override
  Widget build(BuildContext context) {
    final c = clock;
    final weekend = day.weekday >= DateTime.saturday;

    final row = SizedBox(
      height: _rowH,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: first ? null : const Border(top: BorderSide(color: Wb.hair)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _dateWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: Wb.pad),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${kDowNames[day.weekday - 1]} ${day.day} '
                            '${kMonNames[day.month - 1].substring(0, 3)}',
                            style: Wb.ui(
                              size: 12.5,
                              weight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              // A weekend is not an exception to flag — plenty
                              // of shops open on Saturday — so it is only
                              // drawn back, the way a calendar draws one.
                              color: weekend && !isToday ? Wb.muted2 : Wb.ink,
                            ),
                          ),
                          if (isToday)
                            Text(
                              'TODAY',
                              style: Wb.kicker(
                                size: 8.5,
                                tracking: 0.12,
                              ).copyWith(color: Wb.primary),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      c == null ? '—' : '${c.paid.toStringAsFixed(1)}h',
                      style: Wb.code(
                        size: 12,
                        color: c == null ? Wb.closed2 : Wb.body,
                        tracking: -0.01,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _GridPainter(window: window),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (c != null)
                        Positioned(
                          left: window.pctOf(c.inHour) * box.maxWidth,
                          width: (c.paid / window.span) * box.maxWidth,
                          top: 8,
                          bottom: 8,
                          child: _Bar(clock: c),
                        ),
                      // ⚠️ Over this lane only — see the library note.
                      if (isToday)
                        Positioned(
                          left: window.pctOf(kNowHour) * box.maxWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 1.5, color: Wb.primary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: Wb.pad),
          ],
        ),
      ),
    );

    return ahead ? Opacity(opacity: 0.5, child: row) : row;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.clock});
  final ClockHours clock;

  @override
  Widget build(BuildContext context) {
    final open = clock.forgotten;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: open ? Wb.accentSoft : Wb.shiftBg,
        borderRadius: BorderRadius.circular(8),
        border: open ? null : Border.all(color: Wb.shiftBd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${formatHour(clock.inHour)} – ${formatHour(clock.outHour)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Wb.code(
              size: 11,
              color: open ? Wb.accentDark : Wb.shiftFg,
              tracking: -0.01,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.window});
  final DayWindow window;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Wb.hair
      ..strokeWidth = 1;
    for (var h = window.start.ceil(); h <= window.end.floor(); h++) {
      final x = crispLine(window.pctOf(h.toDouble()) * size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.window.start != window.start;
}
