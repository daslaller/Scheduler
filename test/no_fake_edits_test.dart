/// **Over a real punch log the board states hours; it never edits them.**
///
/// `nudge` writes a `ClockOverride`, and `clockOf` reads an override *instead
/// of* the history — so a drag on a shift somebody actually worked discarded
/// their punches and redrew the row from the technician's planned window.
/// Anna's real 08:45–17:10 became 09:00–17:00, on screen, looking like an edit
/// that had taken. Nothing was written either way: `nudge` emits no
/// `ClockEvent`, so no host hears about it and a reload reverts it.
///
/// A defect about somebody's pay, in a control that looked live. Both halves
/// are held here: the write cannot happen, and nothing that cannot act is
/// drawn as though it can.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rx_scheduler/scheduler.dart';
import 'package:rx_scheduler/widgets/chrome.dart';

const _anna = Technician(
  id: 'a',
  name: 'Anna Berg',
  role: 'Technician',
  initial: 'AB',
  cert: '',
  tint: Color(0xFFDBEAFE),
  clockIn: 9,
  clockOut: 17,
  breakAt: 12,
);

RxSchedulerController _ctrl({bool history = true}) => RxSchedulerController(
  technicians: const [_anna],
  seedOnTheClock: false,
  history: history
      ? (id, day) =>
            const ClockHours(inHour: 8.75, outHour: 17.16, breakAt: 12)
      : null,
);

void main() {
  test('a nudge cannot touch a real punch log', () {
    final c = _ctrl();
    addTearDown(c.dispose);
    final before = c.clockOf(0);
    expect(before.inHour, closeTo(8.75, 1e-9));

    c.nudge(0, inSide: true, delta: -0.5);
    c.nudge(0, inSide: false, delta: 1.5);

    final after = c.clockOf(0);
    // Unmoved — and, critically, NOT fallen back to the planned 9–17. That
    // fallback is the defect: it showed invented hours for a real person.
    expect(after.inHour, closeTo(8.75, 1e-9));
    expect(after.outHour, closeTo(17.16, 1e-9));
  });

  test('and it still nudges a rota, which is what it is for', () {
    final c = _ctrl(history: false);
    addTearDown(c.dispose);
    expect(c.clockOf(0).inHour, 9);
    c.nudge(0, inSide: true, delta: -0.5);
    expect(c.clockOf(0).inHour, 8.5);
  });

  testWidgets('no grip and no stepper over a real log', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _ctrl();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: RxScheduler(controller: c)));
    await tester.pump();

    expect(find.byType(StepperChip), findsNothing);
    expect(find.byType(ReadOnlyChip), findsWidgets);
    // The bar's spine is still drawn — it marks where the shift starts — but
    // it offers no resize cursor, because there is nothing to resize.
    expect(
      find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      ),
      findsNothing,
    );
  });

  testWidgets('a rota still has both', (tester) async {
    tester.view.physicalSize = const Size(1400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _ctrl(history: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(home: RxScheduler(controller: c)));
    await tester.pump();

    expect(find.byType(StepperChip), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
      ),
      findsWidgets,
    );
  });
}
