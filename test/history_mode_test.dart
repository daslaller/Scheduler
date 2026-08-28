/// **A board over a real punch log states only what the log holds.**
///
/// This is the rule the approval state already followed and everything else
/// did not, and the gap shipped: RepairX wired the package to its own punches
/// and the board still offered `Approve 4 sheets`, reported a utilisation
/// against a capacity nobody set, and printed a billable figure in dollars —
/// in a product that bills in kronor. None of it was visible in a diff; all of
/// it was obvious in a screenshot.
///
/// So the claim is asserted as a claim: over a history, none of these strings
/// may reach the screen. A regex over the source would not do — the point is
/// what a person reads, and half of these come from a controller getter three
/// files from the widget that draws it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rx_scheduler/models.dart';
import 'package:rx_scheduler/scheduler.dart';
import 'package:rx_scheduler/widgets/month_overlay.dart';

/// Each with the reason it cannot be true of a punch log.
const _fabricated = <String, String>{
  'Utilisation': 'a fraction of contracted hours, which are not punched',
  'Billable labour': 'a rate card, which is not punched',
  'parts excluded': 'the billable tile it belongs to',
  '3 slots after 3pm': 'a bookable-slot model that does not exist',
  'Copy last week': 'writes a rota; there is no rota to copy',
  'Approve 4 sheets': 'a sign-off model that does not exist',
  '4 sheets approved': 'the same, once tapped',
  'walk-in SLA': 'a coverage target nobody set',
  'Over 8h': 'a rota alarm — a full day of work is not a problem',
  'Repairs': 'an appointed-jobs track a punch log has none of',
  'Drag either end': 'a punch is corrected by stating a time, not nudging one',
};

/// The month overlay's own set — same rule, a surface later.
const _fabricatedMonth = <String, String>{
  'flagged for review': 'a review queue that does not exist',
  'Closed': 'asserts the shop was shut; a punch log only says nobody punched',
  'days signed off': 'a sign-off model that does not exist',
};

void main() {
  testWidgets('over a real history the board invents nothing', (tester) async {
    final ctrl = RxSchedulerController(
      technicians: const [
        Technician(
          id: 'a',
          name: 'Anna Berg',
          role: 'Technician',
          initial: 'AB',
          cert: '',
          tint: Color(0xFFDBEAFE),
        ),
      ],
      seedOnTheClock: false,
      history: (id, day) =>
          const ClockHours(inHour: 8.75, outHour: 17.16, breakAt: 12, breakHours: 0.75),
    );
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(home: RxScheduler(controller: ctrl)),
    );
    await tester.pump();

    for (final entry in _fabricated.entries) {
      expect(
        find.textContaining(entry.key),
        findsNothing,
        reason: '"${entry.key}" is ${entry.value}',
      );
    }
  });

  testWidgets('and it says what the log DOES hold', (tester) async {
    final ctrl = RxSchedulerController(
      technicians: const [
        Technician(
          id: 'a',
          name: 'Anna Berg',
          role: 'Technician',
          initial: 'AB',
          cert: '',
          tint: Color(0xFFDBEAFE),
        ),
      ],
      seedOnTheClock: false,
      history: (id, day) =>
          const ClockHours(inHour: 8.75, outHour: 17.16, breakAt: 12, breakHours: 0.75),
    );
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(home: RxScheduler(controller: ctrl)));
    await tester.pump();

    // 24-hour, because a shop reconciling a timesheet reads the punch back as
    // it was made — `8:45a` is a reading of it.
    expect(find.textContaining('08:45 – 17:10'), findsOneWidget);
    // ⚠️ The break length was hardcoded to `30m` whatever the punches said.
    expect(find.textContaining('45m break'), findsOneWidget);
    expect(find.text('Peak bench'), findsOneWidget);
    expect(find.text('On break'), findsOneWidget);
  });

  testWidgets('nor does the month overlay', (tester) async {
    final ctrl = RxSchedulerController(
      technicians: const [
        Technician(
          id: 'a',
          name: 'Anna Berg',
          role: 'Technician',
          initial: 'AB',
          cert: '',
          tint: Color(0xFFDBEAFE),
        ),
      ],
      seedOnTheClock: false,
      // One settled day, and one nobody clocked out of.
      history: (id, day) => day.day == 24
          ? const ClockHours(inHour: 8, outHour: 16, breakAt: 12)
          : day.day == 25
          ? const ClockHours(inHour: 7, outHour: 30, breakAt: 0, open: true)
          : null,
    );
    addTearDown(ctrl.dispose);

    // The overlay is a board; at the harness's default 800x600 it overflows
    // and the failure is the surface, not the claim.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMonthOverlay(context, ctrl: ctrl),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final entry in _fabricatedMonth.entries) {
      expect(
        find.textContaining(entry.key),
        findsNothing,
        reason: '"${entry.key}" is ${entry.value}',
      );
    }
    expect(find.textContaining('Nobody clocked in'), findsWidgets);

    // ⚠️ **Overtime counts settled runs only.** The 23-hour open run above is
    // a cap the clock reached, so reporting 15h of overtime off it measures a
    // punch nobody made. The settled 8-hour day contributes none either.
    expect(find.text('0.0h'), findsOneWidget);
  });

  test('a break is a band of the run, and it stays inside it', () {
    const c = ClockHours(inHour: 8, outHour: 16, breakAt: 12, breakHours: 1);
    final (at, w) = c.breakBand;
    expect(at, closeTo(0.5, 1e-9));
    expect(w, closeTo(0.125, 1e-9));

    // A break recorded past the clock-out is a punch to fix, not a licence to
    // paint outside the shift.
    const bad = ClockHours(inHour: 8, outHour: 16, breakAt: 20, breakHours: 4);
    final (at2, w2) = bad.breakBand;
    expect(at2, 1.0);
    expect(w2, 0.0);
  });

  test('the week number is derived, not a literal', () {
    // It was `31 + row`, so every month of every year reported weeks 31-36.
    expect(isoWeekOf(DateTime(2026, 8, 24)), 35);
    expect(isoWeekOf(DateTime(2026, 1, 1)), 1);
    // A Thursday decides the year: 2027-01-01 is a Friday, so it belongs to
    // the last week of 2026.
    expect(isoWeekOf(DateTime(2027, 1, 1)), 53);
  });
}
