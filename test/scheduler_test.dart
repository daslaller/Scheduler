import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rx_scheduler/controller.dart';
import 'package:rx_scheduler/main.dart';
import 'package:rx_scheduler/models.dart';
import 'package:rx_scheduler/rx_scheduler.dart';
import 'package:rx_scheduler/toast.dart';

void main() {
  test('formatHour matches mockup labels', () {
    expect(formatHour(8), '8a');
    expect(formatHour(13.75), '1:45p');
    expect(formatHour(16.5), '4:30p');
    expect(formatHour(12), '12p');
    expect(formatHour(0), '12a');
  });

  test('Monday 24 August 2026 is the default bench day', () {
    final d = DateTime(2026, 8, 24);
    expect(kDayNames[d.weekday % 7], 'Monday');
    expect(kMonNames[7], 'August');
  });

  test('clock nudge keeps a 30-minute minimum shift', () {
    final c = SchedulerController();
    final before = c.clockOf(0);
    expect(before.inHour, 13);
    expect(before.outHour, 19);
    c.nudge(0, inSide: false, delta: -0.5);
    expect(c.clockOf(0).outHour, 18.5);
    c.nudge(0, inSide: true, delta: 20);
    expect(
      c.clockOf(0).outHour - c.clockOf(0).inHour,
      greaterThanOrEqualTo(0.5),
    );
  });

  test('day meta marks weekday crews as at least three technicians', () {
    final wed = dayMeta(7, 5);
    expect(wed.crewN, greaterThanOrEqualTo(3));
  });

  test('settled and still-running hours are kept apart', () {
    // ⚠️ The rule the whole feature turns on: adding them is what a
    // four-column timesheet does, and it is how a forgotten punch reaches
    // payroll as an ordinary number that grew all weekend.
    final c = SchedulerController();
    final split = c.payableSplit;
    expect(split.open, greaterThan(0), reason: 'somebody has not clocked out');
    expect(split.settled + split.open, closeTo(c.totalHours, 0.001));
    expect(c.capacity, 59.5);
  });

  test('a shift you are standing in is not a fix', () {
    final c = SchedulerController();
    // Two clocks are open; only the one nobody could still be standing in is
    // an alarm. Counting today's live clock-in is how the tile stops being
    // read by lunchtime on the first day.
    expect(c.liveCount, 1);
    expect(c.forgottenCount, 1);
    expect(c.clockOf(4).live, isTrue);
    expect(c.clockOf(3).forgotten, isTrue);
  });

  test('only a punch may widen the day window', () {
    // An open run's end is a *cap*, not a punch. Counted as evidence, one
    // forgotten clock-out puts the board on a 24-hour axis and squashes every
    // real shift to a third of its width.
    final wide = DayWindow.of(const [
      ClockHours(inHour: 9, outHour: 17, breakAt: 0),
      ClockHours(inHour: 10, outHour: 23.5, breakAt: 0, open: true),
    ]);
    expect(wide.end, lessThanOrEqualTo(17));
    expect(wide.start, 9);
  });

  test('a day with nothing punched falls back rather than collapsing', () {
    final empty = DayWindow.of(const <ClockHours>[]);
    expect(empty.start, kDayStart);
    expect(empty.end, kDayEnd);
  });

  test('the month projects onto one technician unchanged', () {
    // What lets the self view reuse the admin month rather than fork it.
    final all = dayMeta(7, 5);
    final mine = onlyTech(all, 0);
    expect(mine.perTech.length, all.perTech.length);
    expect(mine.hours, all.perTech[0]);
    expect(mine.crewN, all.perTech[0] > 0 ? 1 : 0);
    for (var i = 1; i < mine.perTech.length; i++) {
      expect(mine.perTech[i], 0);
    }
  });

  test('a hairline is snapped to the pixel grid', () {
    // Skia spreads a 1px line at a fractional x across two columns at half
    // strength each, which reads as blur rather than as a fainter line.
    expect(crispLine(290.4), 290.5);
    expect(crispLine(12.0), 12.5);
  });

  test('demo seeds punches from the frozen now line', () {
    final c = RxSchedulerController();
    expect(c.isOnTheClock('ak'), isTrue); // 13–19, now 13:45
    expect(c.isOnTheClock('pr'), isTrue); // 8–16:30
    expect(c.isOnTheClock('bh'), isFalse); // 10–13, already out
    c.dispose();
  });

  test('clock in / out from another app uses technician id', () {
    final c = RxSchedulerController(seedOnTheClock: false);
    expect(c.isOnTheClock('ak'), isFalse);

    final events = <ClockEvent>[];
    final toasts = <RxToastMessage>[];
    c.clockEvents.listen(events.add);
    c.toasts.listen(toasts.add);

    final missed = c.clockOut('ak');
    expect(missed.ok, isFalse);
    expect(missed.message, contains('not on the clock'));

    final inn = c.clockIn('ak');
    expect(inn.ok, isTrue);
    expect(c.isOnTheClock('ak'), isTrue);
    expect(c.hoursFor('ak')!.inHour, 13.75);

    final again = c.clockIn('ak');
    expect(again.ok, isFalse);
    expect(again.message, contains('already on the clock'));

    final out = c.clockOut('ak', at: DateTime(2026, 8, 24, 16, 30));
    expect(out.ok, isTrue);
    expect(c.isOnTheClock('ak'), isFalse);
    expect(c.hoursFor('ak')!.outHour, 16.5);

    final unknown = c.clockIn('nope');
    expect(unknown.ok, isFalse);

    expect(events.map((e) => e.action), [ClockAction.clockIn, ClockAction.clockOut]);
    expect(toasts, isNotEmpty);

    final silent = RxSchedulerController(seedOnTheClock: false);
    final silentToasts = <RxToastMessage>[];
    silent.toasts.listen(silentToasts.add);
    silent.clockIn('ak', silent: true);
    expect(silentToasts, isEmpty);
    expect(silent.isOnTheClock('ak'), isTrue);

    c.dispose();
    silent.dispose();
  });

  testWidgets('workbench renders the workshop title and KPIs', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RxSchedulerDemoApp());
    await tester.pump();
    expect(find.textContaining('Northline Device Repair'), findsOneWidget);
    expect(find.text('Monday 24 August'), findsOneWidget);
    expect(find.text('On the bench'), findsOneWidget);
    expect(find.text('Alex Kim (you)'), findsOneWidget);
    expect(find.text('BENCH COVERAGE'), findsOneWidget);
  });

  testWidgets('clock out toast appears above an open technician sheet', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ctrl = RxSchedulerController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => RxToastHost(
          controller: ctrl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: RxScheduler(controller: ctrl),
      ),
    );
    await tester.pump();

    ctrl.openSheet(0);
    await tester.pump();
    expect(find.text('Clock in'), findsWidgets);
    expect(find.text('Clock out'), findsWidgets);

    ctrl.clockOut('ak');
    await tester.pump();
    expect(find.textContaining('clocked out'), findsOneWidget);
  });
}
